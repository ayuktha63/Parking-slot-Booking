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

// Register User
app.post('/api/register', async (req, res) => {
    const { phone, name, car_number_plate, bike_number_plate } = req.body;
    const db = await dbPromise;

    try {
        console.log(`Registering user with phone: ${phone}`);
        const existingUser = await db.collection('users').findOne({ phone });
        if (existingUser) {
            console.log(`User with phone ${phone} already exists`);
            return res.status(200).json({ message: "User already exists" });
        }

        const user = {
            phone,
            name: name || "",
            car_number_plate: car_number_plate || "",
            bike_number_plate: bike_number_plate || "",
            createdAt: new Date(),
        };
        const result = await db.collection('users').insertOne(user);
        console.log(`User registered successfully with ID: ${result.insertedId}`);
        res.status(200).json({ message: "User registered in MongoDB" });
    } catch (error) {
        console.error("Error registering user:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Verify OTP
app.post('/api/verify-otp', async (req, res) => {
    const { phone } = req.body;
    const db = await dbPromise;

    try {
        console.log(`Verifying OTP for phone: ${phone}`);
        const user = await db.collection('users').findOne({ phone });
        if (!user) {
            console.log(`User with phone ${phone} not found`);
            return res.status(404).json({ message: "User not found" });
        }
        console.log(`OTP verified for phone: ${phone}`);
        res.status(200).json({ message: "OTP verified by Firebase" });
    } catch (error) {
        console.error("Error verifying OTP:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Get User Profile
app.get('/api/profile', async (req, res) => {
    const { phone } = req.query;
    const db = await dbPromise;

    try {
        console.log(`Fetching profile for phone: ${phone}`);
        const user = await db.collection('users').findOne({ phone });
        if (user) {
            console.log(`Profile found for phone: ${phone}`, user);
            res.json(user);
        } else {
            console.log(`Profile not found for phone: ${phone}`);
            res.status(404).json({ message: "User not found" });
        }
    } catch (error) {
        console.error("Error fetching profile:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Update User Profile
app.put('/api/profile', async (req, res) => {
    const { phone } = req.query;
    const { name, car_number_plate, bike_number_plate } = req.body;
    const db = await dbPromise;

    try {
        console.log(`Updating profile for phone: ${phone} with data:`, { name, car_number_plate, bike_number_plate });
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
            console.log(`Profile updated for phone: ${phone}`, result);
            res.json({ message: "Profile updated" });
        } else {
            console.log(`No changes made to profile for phone: ${phone}`);
            res.status(400).json({ message: "No changes made" });
        }
    } catch (error) {
        console.error("Error updating profile:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Get Parking Areas
app.get('/api/parking_areas', async (req, res) => {
    const db = await dbPromise;

    try {
        console.log("Fetching all parking areas...");
        const parkingAreas = await db.collection('parking_areas').find().toArray();
        console.log("Parking areas fetched:", parkingAreas);
        if (parkingAreas.length === 0) {
            console.log("No parking areas found in database");
            return res.status(200).json([]);
        }
        res.json(parkingAreas);
    } catch (error) {
        console.error("Error fetching parking areas:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Create Parking Area
app.post('/api/parking_areas', async (req, res) => {
    const { name, location, total_car_slots, total_bike_slots } = req.body;
    const db = await dbPromise;

    try {
        console.log("Creating parking area with data:", { name, location, total_car_slots, total_bike_slots });
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
        console.log(`Parking area created with ID: ${result.insertedId}`);

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
        const slotsResult = await db.collection('slots').insertMany([...carSlots, ...bikeSlots]);
        console.log(`Inserted ${slotsResult.insertedCount} slots (car: ${total_car_slots}, bike: ${total_bike_slots}) for parking_id: ${result.insertedId}`);

        res.json({ id: result.insertedId });
    } catch (error) {
        console.error("Error creating parking area:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Get Available Slots
app.get('/api/parking_areas/:id/slots', async (req, res) => {
    const db = await dbPromise;
    const { entry_time, exit_time } = req.query;
    const parkingId = new ObjectId(req.params.id);

    let query = { parking_id: parkingId, status: "available" };

    if (entry_time && exit_time) {
        const entryTime = new Date(entry_time);
        const exitTime = new Date(exit_time);

        // Find slots that are not booked during the requested time range
        const conflictingBookings = await db.collection('bookings')
            .find({
                parking_id: parkingId,
                status: "active",
                $or: [
                    { entry_time: { $lt: exitTime }, exit_time: { $gt: entryTime } }
                ]
            })
            .toArray();

        const bookedSlotIds = conflictingBookings.map(b => b.slot_id.toString());
        query = {
            parking_id: parkingId,
            status: "available",
            _id: { $nin: bookedSlotIds.map(id => new ObjectId(id)) }
        };
    }

    const slots = await db.collection('slots').find(query).toArray();
    res.json(slots);
});

// Debug Endpoint: Get All Slots (Available or Booked)
app.get('/api/parking_areas/:id/all-slots', async (req, res) => {
    const db = await dbPromise;

    try {
        console.log(`Fetching all slots for parking_id: ${req.params.id}`);
        if (!ObjectId.isValid(req.params.id)) {
            console.log(`Invalid parking area ID: ${req.params.id}`);
            return res.status(400).json({ message: "Invalid parking area ID" });
        }

        const parkingId = new ObjectId(req.params.id);
        const parkingArea = await db.collection('parking_areas').findOne({ _id: parkingId });
        if (!parkingArea) {
            console.log(`Parking area not found for ID: ${req.params.id}`);
            return res.status(404).json({ message: "Parking area not found" });
        }
        console.log(`Parking area found:`, parkingArea);

        const slots = await db.collection('slots').find({ parking_id: parkingId }).toArray();
        console.log(`All slots fetched for parking_id ${req.params.id}:`, slots);
        res.json(slots);
    } catch (error) {
        console.error(`Error fetching all slots for parking_id ${req.params.id}:`, error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Book a Slot
app.post('/api/bookings', async (req, res) => {
    const { parking_id, slot_id, vehicle_type, number_plate, entry_time, exit_time } = req.body;
    const db = await dbPromise;

    try {
        console.log("Booking slot with data:", { parking_id, slot_id, vehicle_type, number_plate, entry_time, exit_time });
        if (!ObjectId.isValid(parking_id) || !ObjectId.isValid(slot_id)) {
            console.log(`Invalid IDs - parking_id: ${parking_id}, slot_id: ${slot_id}`);
            return res.status(400).json({ message: "Invalid parking_id or slot_id" });
        }

        const slot = await db.collection('slots').findOne({
            _id: new ObjectId(slot_id),
            status: "available",
            vehicle_type: vehicle_type.toLowerCase()
        });

        if (!slot) {
            console.log(`Slot not available or mismatched vehicle type for slot_id: ${slot_id}`);
            return res.status(400).json({ message: "Slot not available or mismatched vehicle type" });
        }
        console.log(`Slot found:`, slot);

        const entryDate = new Date(entry_time);
        const exitDate = exit_time ? new Date(exit_time) : null;

        if (isNaN(entryDate) || (exit_time && isNaN(exitDate))) {
            console.log("Invalid time format detected");
            return res.status(400).json({ message: "Invalid entry_time or exit_time format" });
        }

        const conflictingBooking = await db.collection('bookings').findOne({
            slot_id: new ObjectId(slot_id),
            status: "active",
            $or: [
                { entry_time: { $lte: exitDate || entryDate }, exit_time: { $gte: entryDate } },
                { entry_time: { $lte: exitDate || entryDate }, exit_time: null }
            ]
        });

        if (conflictingBooking) {
            console.log(`Conflict found for slot_id: ${slot_id}`, conflictingBooking);
            return res.status(400).json({ message: "Slot is already booked for this time range" });
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
        console.log(`Booking created with ID: ${result.insertedId}`);

        await db.collection('slots').updateOne(
            { _id: new ObjectId(slot_id) },
            { $set: { status: "booked", current_booking_id: result.insertedId } }
        );
        console.log(`Slot ${slot_id} updated to booked`);

        const updateField = vehicle_type.toLowerCase() === "car"
            ? { $inc: { available_car_slots: -1, booked_car_slots: 1 } }
            : { $inc: { available_bike_slots: -1, booked_bike_slots: 1 } };
        await db.collection('parking_areas').updateOne(
            { _id: new ObjectId(parking_id) },
            updateField
        );
        console.log(`Parking area ${parking_id} counters updated`);

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

// Start Server
app.listen(3000, () => console.log("Server running on port 3000"));