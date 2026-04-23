# DRIVORA Cloud Server Setup Guide

## Overview
This guide provides step-by-step instructions to set up the DRIVORA backend server for data storage, processing, and real-time sensor data handling.

---

## Architecture Overview

```
┌─────────────────┐          ┌──────────────────┐          ┌─────────────────┐
│  Flutter App    │◄────────►│   WiFi Hub/REST  │◄────────►│  Cloud Server   │
│   (Frontend)    │          │   API Endpoint   │          │   (Backend)     │
└─────────────────┘          └──────────────────┘          └─────────────────┘
                                                                      │
                                                    ┌──────────────────┼──────────────────┐
                                                    │                  │                  │
                                            ┌───────▼────┐      ┌────▼────────┐  ┌─────▼──────┐
                                            │  Database  │      │ Auth Server │  │ WebSocket  │
                                            │ (MongoDB)  │      │  (Firebase) │  │  (Real-time)│
                                            └────────────┘      └─────────────┘  └────────────┘
```

---

## Prerequisites

- **Node.js** (v16+)
- **npm** (v8+)
- **MongoDB** Atlas Account (free tier available)
- **Firebase** Account (for authentication)
- **AWS/Google Cloud** Account (optional, for deployment)
- **Docker** (optional, for containerization)

---

## Step 1: Database Setup (MongoDB)

### 1.1 Create MongoDB Atlas Cluster

1. Go to [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
2. Create a free account
3. Create a new project called "DRIVORA"
4. Click "Create Deployment"
5. Choose:
   - **Cluster Tier**: M0 (Free)
   - **Cloud Provider**: AWS/GCP/Azure (your choice)
   - **Region**: Closest to you
6. Create a database user:
   - Username: `drivora_user`
   - Password: `SecurePassword123!`
   - Grant admin access temporarily for setup
7. Add your IP to the IP Whitelist (or allow 0.0.0.0/0 for development)
8. Get the connection string (looks like):
   ```
   mongodb+srv://drivora_user:SecurePassword123!@drivora-cluster.xxxxx.mongodb.net/?retryWrites=true&w=majority
   ```

### 1.2 Create Database Collections

Once connected, create these collections:

```javascript
// vehicles
{
  _id: ObjectId,
  userId: String,
  name: String,
  model: String,
  email: String,
  registrationDate: Date,
  deviceId: String,
  createdAt: Date
}

// sensorData
{
  _id: ObjectId,
  vehicleId: ObjectId,
  timestamp: Date,
  speed: Number,
  latitude: Number,
  longitude: Number,
  lanePosition: Number,
  tiltAngle: Number,
  brakeActive: Boolean,
  leftSignal: Boolean,
  rightSignal: Boolean,
  fcwDistance: Number,
  ldwActive: Boolean,
  bsmActive: Boolean,
  safetyScore: Number,
  dataSource: String,
  createdAt: Date
}

// alerts
{
  _id: ObjectId,
  vehicleId: ObjectId,
  type: String,
  severity: String,
  message: String,
  timestamp: Date,
  location: { type: "Point", coordinates: [lng, lat] },
  resolved: Boolean,
  createdAt: Date
}

// drivingSession
{
  _id: ObjectId,
  vehicleId: ObjectId,
  startTime: Date,
  endTime: Date,
  distance: Number,
  avgSpeed: Number,
  maxSpeed: Number,
  safetyScore: Number,
  alertsTriggered: Number,
  route: [{ latitude: Number, longitude: Number }],
  createdAt: Date
}
```

---

## Step 2: Node.js/Express Backend Setup

### 2.1 Create Backend Project

```bash
mkdir drivora-backend
cd drivora-backend
npm init -y
npm install express mongoose dotenv cors helmet bcryptjs jsonwebtoken firebase-admin axios
npm install --save-dev nodemon
```

### 2.2 Create Project Structure

```
drivora-backend/
├── config/
│   └── db.js
├── controllers/
│   ├── vehicleController.js
│   ├── sensorController.js
│   ├── alertController.js
│   └── sessionController.js
├── middleware/
│   ├── auth.js
│   └── errorHandler.js
├── routes/
│   ├── vehicles.js
│   ├── sensors.js
│   ├── alerts.js
│   └── sessions.js
├── models/
│   ├── Vehicle.js
│   ├── SensorData.js
│   ├── Alert.js
│   └── Session.js
├── .env
├── .gitignore
├── server.js
└── package.json
```

### 2.3 Environment File (.env)

```env
# Server
PORT=5000
NODE_ENV=development

# MongoDB
MONGODB_URI=mongodb+srv://drivora_user:SecurePassword123!@drivora-cluster.xxxxx.mongodb.net/?retryWrites=true&w=majority
DB_NAME=drivora

# Firebase
FIREBASE_API_KEY=your_firebase_api_key
FIREBASE_AUTH_DOMAIN=your_firebase_project.firebaseapp.com
FIREBASE_PROJECT_ID=your_firebase_project_id
FIREBASE_STORAGE_BUCKET=your_firebase_project.appspot.com
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_APP_ID=your_app_id

# JWT
JWT_SECRET=your_super_secret_jwt_key_here_min_32_chars

# CORS
CORS_ORIGIN=http://localhost:3000,http://localhost:8080

# Logging
LOG_LEVEL=debug
```

### 2.4 Server Entry Point (server.js)

```javascript
require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');

const app = express();

// Middleware
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN?.split(','),
  credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ limit: '10mb', extended: true }));

// Database Connection
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => console.log('✓ MongoDB Connected'))
.catch(err => console.error('✗ MongoDB Error:', err));

// Routes
app.use('/api/vehicles', require('./routes/vehicles'));
app.use('/api/sensors', require('./routes/sensors'));
app.use('/api/alerts', require('./routes/alerts'));
app.use('/api/sessions', require('./routes/sessions'));

// Health Check
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date() });
});

// Error Handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal Server Error'
  });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`🚀 DRIVORA Backend running on port ${PORT}`);
});
```

### 2.5 Vehicle Model (models/Vehicle.js)

```javascript
const mongoose = require('mongoose');

const vehicleSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true },
  name: { type: String, required: true },
  model: { type: String, required: true },
  email: { type: String, required: true },
  deviceId: { type: String, unique: true, required: true },
  registrationDate: { type: Date, default: Date.now },
  isActive: { type: Boolean, default: true },
  metadata: {
    vin: String,
    color: String,
    year: Number,
    features: [String]
  }
}, { timestamps: true });

vehicleSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Vehicle', vehicleSchema);
```

### 2.6 Sensor Data Model (models/SensorData.js)

```javascript
const mongoose = require('mongoose');

const sensorDataSchema = new mongoose.Schema({
  vehicleId: { type: mongoose.Schema.Types.ObjectId, ref: 'Vehicle', required: true },
  timestamp: { type: Date, default: Date.now, index: true },
  speed: { type: Number, min: 0, max: 300 },
  location: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: [Number] // [longitude, latitude]
  },
  lanePosition: { type: Number, min: -1, max: 1 },
  tiltAngle: { type: Number },
  brakeActive: Boolean,
  leftSignal: Boolean,
  rightSignal: Boolean,
  fcwDistance: Number,
  ldwActive: Boolean,
  bsmActive: Boolean,
  safetyScore: { type: Number, min: 0, max: 1 },
  dataSource: { type: String, enum: ['WiFi', 'Simulation', 'RawData'] },
  alertsTriggered: [String]
}, { timestamps: true });

sensorDataSchema.index({ vehicleId: 1, timestamp: -1 });
sensorDataSchema.index({ location: '2dsphere' });

module.exports = mongoose.model('SensorData', sensorDataSchema);
```

### 2.7 Sensor Data Route (routes/sensors.js)

```javascript
const express = require('express');
const router = express.Router();
const SensorData = require('../models/SensorData');
const authMiddleware = require('../middleware/auth');

// Save sensor data (from Flutter app)
router.post('/save', authMiddleware, async (req, res) => {
  try {
    const { vehicleId, speed, latitude, longitude, ...otherData } = req.body;

    const sensorData = new SensorData({
      vehicleId,
      speed,
      location: {
        type: 'Point',
        coordinates: [longitude, latitude]
      },
      ...otherData,
      timestamp: new Date()
    });

    await sensorData.save();

    res.status(201).json({
      success: true,
      message: 'Sensor data saved',
      data: sensorData
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get real-time sensor data
router.get('/realtime/:vehicleId', authMiddleware, async (req, res) => {
  try {
    const { vehicleId } = req.params;
    const recentData = await SensorData.findOne({ vehicleId })
      .sort({ timestamp: -1 });

    res.json({
      success: true,
      data: recentData
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get sensor history
router.get('/history/:vehicleId', authMiddleware, async (req, res) => {
  try {
    const { vehicleId } = req.params;
    const { limit = 100, skip = 0 } = req.query;

    const data = await SensorData.find({ vehicleId })
      .sort({ timestamp: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(skip));

    const total = await SensorData.countDocuments({ vehicleId });

    res.json({
      success: true,
      data,
      pagination: { total, limit, skip }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
```

---

## Step 3: Flutter App Backend Integration

### 3.1 Create Backend Service

Create file: `lib/services/backend_service.dart`

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/sensor_data.dart';

class BackendService {
  static const String baseUrl = 'https://your-backend-url.com/api';
  static String? _authToken;

  static Future<void> initialize(String token) async {
    _authToken = token;
  }

  static Future<bool> saveSensorData(SensorData data, String vehicleId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sensors/save'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'vehicleId': vehicleId,
          'speed': data.speed,
          'latitude': data.latitude,
          'longitude': data.longitude,
          'lanePosition': data.lanePosition,
          'tiltAngle': data.tiltAngle,
          'brakeActive': data.brakeActive,
          'leftSignal': data.leftSignal,
          'rightSignal': data.rightSignal,
          'safetyScore': data.safetyScore,
          'dataSource': data.dataSource,
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      print('Error saving sensor data: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getRealtimeData(String vehicleId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sensors/realtime/$vehicleId'),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching realtime data: $e');
      return null;
    }
  }
}
```

### 3.2 Update WiFiSensorService

Add this to existing `wifi_sensor_service.dart`:

```dart
import 'backend_service.dart';

// Add to WiFiSensorService class:
Future<void> syncDataToCloud() async {
  if (!isConnected) return;

  final sensorData = SensorData(
    speed: speed,
    latitude: 6.9271,
    longitude: 80.7789,
    lanePosition: lanePosition,
    tiltAngle: tiltAngle,
    brakeActive: brakeActive,
    leftSignal: leftSignal,
    rightSignal: rightSignal,
    safetyScore: safetyScore,
    dataSource: dataSource,
  );

  await BackendService.saveSensorData(sensorData, 'vehicle_id_here');
}
```

---

## Step 4: Firebase Authentication Setup

### 4.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project: "DRIVORA"
3. Enable Authentication > Email/Password
4. Enable Firestore Database (optional, for real-time updates)

### 4.2 Flutter Firebase Integration

```bash
flutter pub add firebase_core firebase_auth
flutterfire configure
```

---

## Step 5: Deployment

### Option A: Deploy to Heroku

```bash
# Install Heroku CLI
npm install -g heroku

# Login
heroku login

# Create app
heroku create drivora-backend

# Set environment variables
heroku config:set MONGODB_URI="mongodb+srv://..."
heroku config:set JWT_SECRET="your_secret"

# Deploy
git push heroku main
```

### Option B: Deploy to AWS

1. Create EC2 instance (Ubuntu 20.04)
2. Install Node.js and PM2
3. Clone repository
4. Set environment variables
5. Run with PM2:
   ```bash
   pm2 start server.js --name drivora
   ```

### Option C: Deploy with Docker

Create `Dockerfile`:

```dockerfile
FROM node:16-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 5000
CMD ["npm", "start"]
```

---

## Step 6: Data Persistence & Security

### Data Backup Strategy

- **Daily Backups**: MongoDB Atlas automatic backups (free)
- **Cloud Storage**: AWS S3 for sensor data archives
- **Encryption**: All data encrypted in transit (HTTPS) and at rest

### Security Measures

- ✅ CORS enabled only for Flutter app domain
- ✅ JWT token validation on every request
- ✅ Rate limiting (100 requests/minute per vehicle)
- ✅ Data encryption with bcryptjs
- ✅ Environment variables for secrets
- ✅ HTTPS only (enforce in production)
- ✅ Input validation on all endpoints

---

## Step 7: Monitoring & Logging

### Add Winston Logger

```bash
npm install winston
```

```javascript
// In server.js
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});

// Middleware to log requests
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`);
  next();
});
```

---

## Step 8: Real-Time Updates (Optional WebSocket)

```bash
npm install socket.io
```

```javascript
const io = require('socket.io')(server);

io.on('connection', (socket) => {
  socket.on('vehicle:update', (data) => {
    io.emit('sensor:data', data);
  });
});
```

---

## API Endpoints Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/vehicles/register` | Register new vehicle |
| POST | `/api/sensors/save` | Save sensor data |
| GET | `/api/sensors/realtime/:vehicleId` | Get real-time data |
| GET | `/api/sensors/history/:vehicleId` | Get sensor history |
| POST | `/api/alerts/create` | Create alert |
| GET | `/api/alerts/:vehicleId` | Get vehicle alerts |
| POST | `/api/sessions/start` | Start driving session |
| GET | `/api/sessions/:vehicleId` | Get session history |

---

## Testing

```bash
# Test endpoint
curl -X GET http://localhost:5000/api/health
```

Expected response:
```json
{
  "status": "OK",
  "timestamp": "2024-04-23T12:00:00.000Z"
}
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| MongoDB connection failed | Check whitelist IP, username, password |
| CORS errors | Update CORS_ORIGIN in .env |
| JWT errors | Ensure token is passed in Authorization header |
| Data not saving | Check request body format matches schema |

---

## Support & Resources

- MongoDB Docs: https://docs.mongodb.com
- Express Guide: https://expressjs.com
- Firebase Docs: https://firebase.google.com/docs
- Flutter HTTP: https://pub.dev/packages/http

---

*Last Updated: April 2024*
*DRIVORA U-ADAS Project*
