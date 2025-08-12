const express = require('express');
const { MongoClient, ObjectId } = require('mongodb');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const app = express();
const uri = "mongodb://localhost:27017";
const client = new MongoClient(uri);

app.use(express.json());
app.use(cors({ origin: '*' }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Configure multer for file uploads
const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir);
}

const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'uploads/');
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, `${uniqueSuffix}-${file.originalname}`);
    }
});

const upload = multer({
    storage: storage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
    fileFilter: (req, file, cb) => {
        const extFiletypes = /\.jpeg|\.jpg|\.png/;
        const mimeFiletypes = /image\/(jpeg|png)/;
        const extname = extFiletypes.test(path.extname(file.originalname).toLowerCase());
        const mimetype = mimeFiletypes.test(file.mimetype.toLowerCase());
        if (extname && mimetype) {
            cb(null, true);
        } else {
            cb(new Error('Only JPEG/JPG/PNG images are allowed!'));
        }
    }
});

// Multer Error Handling Middleware
function handleMulterError(err, req, res, next) {
    if (err instanceof multer.MulterError) {
        return res.status(400).json({ message: err.message });
    } else if (err) {
        return res.status(400).json({ message: err.message });
    }
    next();
}

// Database Connection with Retry
async function connectDB() {
    let retries = 5;
    while (retries) {
        try {
            await client.connect();
            console.log("Connected to MongoDB");
            return client.db("ParkingSystem");
        } catch (error) {
            console.error("MongoDB connection failed:", error);
            retries -= 1;
            if (retries === 0) {
                console.error("Max retries reached. Exiting...");
                process.exit(1);
            }
            console.log(`Retrying connection (${5 - retries}/5)...`);
            await new Promise(res => setTimeout(res, 2000));
        }
    }
}

const dbPromise = connectDB();

// Register User
app.post('/api/register', async (req, res) => {
    const { phone, name, car_number_plate, bike_number_plate } = req.body;
    const db = await dbPromise;

    try {
        const existingUser = await db.collection('users').findOne({ phone });
        if (existingUser) {
            return res.status(200).json({ message: "User already exists" });
        }

        const user = {
            phone,
            name: name || "",
            car_number_plate: car_number_plate || "",
            bike_number_plate: bike_number_plate || "",
            profile_image: "",
            createdAt: new Date(),
        };
        const result = await db.collection('users').insertOne(user);
        res.status(200).json({ message: "User registered in MongoDB" });
    } catch (error) {
        console.error("Error registering user:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Get User Profile
app.get('/api/profile', async (req, res) => {
    const { phone } = req.query;
    const db = await dbPromise;

    try {
        const user = await db.collection('users').findOne({ phone });
        if (user) {
            res.json({
                phone: user.phone,
                name: user.name,
                car_number_plate: user.car_number_plate,
                bike_number_plate: user.bike_number_plate,
                profile_image: user.profile_image ? `http://localhost:3000${user.profile_image}` : null
            });
        } else {
            res.status(404).json({ message: "User not found" });
        }
    } catch (error) {
        console.error("Error fetching profile:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Update User Profile (with image upload)
app.put('/api/profile', upload.single('profile_image'), handleMulterError, async (req, res) => {
    const { phone } = req.query;
    const { name, car_number_plate, bike_number_plate } = req.body;
    const db = await dbPromise;

    try {
        const existingUser = await db.collection('users').findOne({ phone });
        if (!existingUser) {
            return res.status(404).json({ message: "User not found" });
        }

        const updateData = {};
        if (name !== undefined) updateData.name = name;
        if (car_number_plate !== undefined) updateData.car_number_plate = car_number_plate;
        if (bike_number_plate !== undefined) updateData.bike_number_plate = bike_number_plate;
        if (req.file) {
            if (existingUser.profile_image) {
                const oldImagePath = path.join(__dirname, existingUser.profile_image);
                if (fs.existsSync(oldImagePath)) {
                    fs.unlinkSync(oldImagePath);
                }
            }
            updateData.profile_image = `/uploads/${req.file.filename}`;
        }
        updateData.updatedAt = new Date();

        const result = await db.collection('users').updateOne(
            { phone },
            { $set: updateData }
        );

        if (result.modifiedCount > 0) {
            res.json({ message: "Profile updated" });
        } else {
            res.status(400).json({ message: "No changes made" });
        }
    } catch (error) {
        console.error("Error updating profile:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Get All Parking Areas
app.get('/api/parking_areas', async (req, res) => {
    const db = await dbPromise;

    try {
        const parkingAreas = await db.collection('parking_areas').find().toArray();
        if (parkingAreas.length === 0) {
            return res.status(200).json([]);
        }
        res.json(parkingAreas);
    } catch (error) {
        console.error("Error fetching parking areas:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Get All Slots for a Parking Area
app.get('/api/parking_areas/:id/slots', async (req, res) => {
    const db = await dbPromise;
    const { vehicle_type } = req.query;

    try {
        const parkingId = new ObjectId(req.params.id);

        if (!ObjectId.isValid(req.params.id)) {
            return res.status(400).json({ message: "Invalid parking area ID" });
        }

        const parkingArea = await db.collection('parking_areas').findOne({ _id: parkingId });
        if (!parkingArea) {
            return res.status(404).json({ message: "Parking area not found" });
        }

        let query = { parking_id: parkingId };
        if (vehicle_type) {
            query.vehicle_type = vehicle_type.toLowerCase();
        }
        const slots = await db.collection('slots').find(query).toArray();

        const activeBookings = await db.collection('bookings')
            .find({ parking_id: parkingId, status: "active" })
            .toArray();
        const bookedSlotIds = activeBookings.map(b => b.slot_id.toString());

        const slotsWithStatus = slots.map(slot => ({
            ...slot,
            is_booked: bookedSlotIds.includes(slot._id.toString())
        }));

        res.json(slotsWithStatus);
    } catch (error) {
        console.error(`Error fetching slots for parking_id ${req.params.id}:`, error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Book a Slot (Fixed Logic)
app.post('/api/bookings', async (req, res) => {
    const { parking_id, slot_id, vehicle_type, number_plate, entry_time, exit_time } = req.body;
    const db = await dbPromise;

    try {
        if (!ObjectId.isValid(parking_id) || !ObjectId.isValid(slot_id)) {
            return res.status(400).json({ message: "Invalid parking_id or slot_id" });
        }

        // Fetch the slot and check its status in a single query
        const slot = await db.collection('slots').findOne({
            _id: new ObjectId(slot_id),
            status: "available", // This is the crucial check
            vehicle_type: vehicle_type.toLowerCase()
        });

        if (!slot) {
            // If the slot is not found or its status is not 'available', it's already booked or invalid.
            return res.status(400).json({ message: "Slot not found or is already booked" });
        }

        const entryDate = new Date(entry_time);
        const exitDate = exit_time ? new Date(exit_time) : null;

        if (isNaN(entryDate) || (exit_time && isNaN(exitDate))) {
            return res.status(400).json({ message: "Invalid entry_time or exit_time format" });
        }

        const booking = {
            parking_id: new ObjectId(parking_id),
            slot_id: new ObjectId(slot_id),
            vehicle_type: vehicle_type.toLowerCase(),
            number_plate,
            entry_time: entryDate,
            exit_time: exitDate,
            status: "active",
            createdAt: new Date()
        };
        const result = await db.collection('bookings').insertOne(booking);

        // Update the slot status to booked and associate the booking ID
        await db.collection('slots').updateOne(
            { _id: new ObjectId(slot_id) },
            { $set: { status: "booked", current_booking_id: result.insertedId } }
        );

        const updateField = vehicle_type.toLowerCase() === "car"
            ? { $inc: { available_car_slots: -1, booked_car_slots: 1 } }
            : { $inc: { available_bike_slots: -1, booked_bike_slots: 1 } };
        await db.collection('parking_areas').updateOne(
            { _id: new ObjectId(parking_id) },
            updateField
        );

        res.json({
            booking_id: result.insertedId,
            slot_number: slot.slot_number,
            vehicle_type: booking.vehicle_type,
            entry_time: booking.entry_time,
            exit_time: booking.exit_time
        });
    } catch (error) {
        console.error("Error booking slot:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

app.listen(3000, () => console.log("Server running on port 3000"));