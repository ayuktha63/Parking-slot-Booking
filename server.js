const express = require('express');
const { MongoClient, ObjectId } = require('mongodb');
const cors = require('cors');
const app = express();
const uri = "mongodb://localhost:27017";
const client = new MongoClient(uri);

app.use(express.json());
app.use(cors()); // Enable CORS for all routes

// Database Connection
async function connectDB() {
    try {
        await client.connect();
        console.log("Connected to MongoDB");
        return client.db("ParkingSystem");
    } catch (error) {
        console.error("MongoDB connection failed:", error);
        process.exit(1);
    }
}

const dbPromise = connectDB();

// Register User (Called after Firebase Auth)
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
            createdAt: new Date(),
        };
        await db.collection('users').insertOne(user);
        res.status(200).json({ message: "User registered in MongoDB" });
    } catch (error) {
        console.error("Error registering user:", error);
        res.status(500).json({ message: "Server error" });
    }
});

// Verify OTP (Placeholder, as Firebase handles this)
app.post('/api/verify-otp', async (req, res) => {
    const { phone } = req.body;
    const db = await dbPromise;

    try {
        const user = await db.collection('users').findOne({ phone });
        if (!user) {
            return res.status(404).json({ message: "User not found" });
        }
        res.status(200).json({ message: "OTP verified by Firebase" });
    } catch (error) {
        console.error("Error verifying OTP:", error);
        res.status(500).json({ message: "Server error" });
    }
});

// Get User Profile
app.get('/api/profile', async (req, res) => {
    const { phone } = req.query;
    const db = await dbPromise;

    try {
        const user = await db.collection('users').findOne({ phone });
        if (user) {
            res.json(user);
        } else {
            res.status(404).json({ message: "User not found" });
        }
    } catch (error) {
        console.error("Error fetching profile:", error);
        res.status(500).json({ message: "Server error" });
    }
});

// Update User Profile
app.put('/api/profile', async (req, res) => {
    const { phone } = req.query;
    const { name, car_number_plate, bike_number_plate } = req.body;
    const db = await dbPromise;

    try {
        const updateData = {};
        if (name !== undefined) updateData.name = name;
        if (car_number_plate !== undefined) updateData.car_number_plate = car_number_plate;
        if (bike_number_plate !== undefined) updateData.bike_number_plate = bike_number_plate;
        updateData.updatedAt = new Date();

        const result = await db.collection('users').updateOne(
            { phone },
            { $set: updateData },
            { upsert: true }
        );

        if (result.modifiedCount > 0 || result.upsertedCount > 0) {
            res.json({ message: "Profile updated" });
        } else {
            res.status(400).json({ message: "No changes made" });
        }
    } catch (error) {
        console.error("Error updating profile:", error);
        res.status(500).json({ message: "Server error" });
    }
});

// Get Parking Areas
app.get('/api/parking_areas', async (req, res) => {
    const db = await dbPromise;

    try {
        const parkingAreas = await db.collection('parking_areas').find().toArray();
        res.json(parkingAreas);
    } catch (error) {
        console.error("Error fetching parking areas:", error);
        res.status(500).json({ message: "Server error" });
    }
});

// Create Parking Area
app.post('/api/parking_areas', async (req, res) => {
    const { name, location, total_car_slots, total_bike_slots } = req.body;
    const db = await dbPromise;

    try {
        const parkingArea = {
            name,
            location: { lat: location.lat, lng: location.lng },
            total_car_slots,
            available_car_slots: total_car_slots,
            booked_car_slots: 0,
            total_bike_slots,
            available_bike_slots: total_bike_slots,
            booked_bike_slots: 0,
        };
        const result = await db.collection('parking_areas').insertOne(parkingArea);

        const carSlots = Array.from({ length: total_car_slots }, (_, i) => ({
            parking_id: result.insertedId,
            slot_number: i + 1,
            vehicle_type: "car",
            status: "available",
            current_booking_id: null,
        }));
        const bikeSlots = Array.from({ length: total_bike_slots }, (_, i) => ({
            parking_id: result.insertedId,
            slot_number: i + 1,
            vehicle_type: "bike",
            status: "available",
            current_booking_id: null,
        }));
        await db.collection('slots').insertMany([...carSlots, ...bikeSlots]);

        res.json({ id: result.insertedId });
    } catch (error) {
        console.error("Error creating parking area:", error);
        res.status(500).json({ message: "Server error" });
    }
});

// Get Available Slots
app.get('/api/parking_areas/:id/slots', async (req, res) => {
    const db = await dbPromise;

    try {
        const slots = await db.collection('slots').find({
            parking_id: new ObjectId(req.params.id),
            status: "available"
        }).toArray();
        res.json(slots);
    } catch (error) {
        console.error("Error fetching slots:", error);
        res.status(500).json({ message: "Server error" });
    }
});

// Book a Slot
app.post('/api/bookings', async (req, res) => {
    const { parking_id, slot_id, vehicle_type, number_plate, entry_time, exit_time } = req.body;
    const db = await dbPromise;

    try {
        const slot = await db.collection('slots').findOne({
            _id: new ObjectId(slot_id),
            status: "available",
            vehicle_type: vehicle_type // Ensure slot matches vehicle type
        });
        if (!slot) {
            return res.status(400).json({ message: "Slot not available or mismatched vehicle type" });
        }

        const booking = {
            parking_id: new ObjectId(parking_id),
            slot_id: new ObjectId(slot_id),
            vehicle_type,
            number_plate,
            entry_time: new Date(entry_time),
            exit_time: exit_time ? new Date(exit_time) : null,
            status: "active",
        };
        const result = await db.collection('bookings').insertOne(booking);

        await db.collection('slots').updateOne(
            { _id: new ObjectId(slot_id) },
            { $set: { status: "booked", current_booking_id: result.insertedId } }
        );

        const updateField = vehicle_type === "car"
            ? { $inc: { available_car_slots: -1, booked_car_slots: 1 } }
            : { $inc: { available_bike_slots: -1, booked_bike_slots: 1 } };
        await db.collection('parking_areas').updateOne(
            { _id: new ObjectId(parking_id) },
            updateField
        );

        res.json({ booking_id: result.insertedId });
    } catch (error) {
        console.error("Error booking slot:", error);
        res.status(500).json({ message: "Server error" });
    }
});

// Start Server
app.listen(3000, () => console.log("Server running on port 3000"));