// server.js (FINAL MERGED VERSION)
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const dotenv = require('dotenv');
const sequelize = require('./config/db');
const path = require('path');
const fs = require('fs');

dotenv.config();

// MODELS
require('./model/index');
require('./model/relations');

const app = express();

// ===========================
// 📌 Middlewares
// ===========================
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ===========================
// 📌 Create required directories
// ===========================
const requiredDirs = [
    'uploads',
    'uploads/children',
    'uploads/evaluations',
    'uploads/profiles'
];

requiredDirs.forEach(dir => {
    const dirPath = path.join(__dirname, dir);
    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
        console.log(`📁 Created directory: ${dir}`);
    }
});

// ===========================
// 📌 Health Check
// ===========================
app.get('/health', async (req, res) => {
    try {
        await sequelize.authenticate();
        const uptime = process.uptime();
        const mem = process.memoryUsage();

        res.status(200).json({
            status: 'healthy',
            uptime: `${Math.floor(uptime / 60)} minutes`,
            memory: {
                rss: `${Math.floor(mem.rss / 1024 / 1024)} MB`,
                heapUsed: `${Math.floor(mem.heapUsed / 1024 / 1024)} MB`,
                heapTotal: `${Math.floor(mem.heapTotal / 1024 / 1024)} MB`
            },
            database: 'connected',
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(503).json({
            status: 'unhealthy',
            database: 'disconnected',
            error: error.message
        });
    }
});

// ===========================
// 📌 Test Route
// ===========================
app.get('/test', (req, res) => {
    res.send('Server is working!');
});

// ===========================
// 📌 ROUTES
// ===========================

// Auth
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/auth', require('./routes/auth'));  // لنحافظ على الإصدارين

// User routes
app.use('/api/users', require('./routes/userRoutes'));

// Parent & Session
app.use('/api/parent', require('./routes/parentRoutes'));
app.use('/api/parent', require('./routes/sessionRoutes'));

// Children
app.use('/api/children', require('./routes/childRoutes'));

// Specialist
app.use('/api/specialist', require('./routes/specialistRoutes'));
app.use('/api/specialist', require('./routes/specialistSessionRoutes'));
app.use('/api/specialist', require('./routes/specialistChildrenRoutes'));
app.use('/api/specialist/approval', require('./routes/specialistApprovalRoutes'));

// Community
app.use('/api/community', require('./routes/communityRoutes'));

// AI Assistant
app.use('/api/ai', require('./routes/aiAdviceRoutes'));

// Chat
app.use('/api/chat', require('./routes/chatRoutes'));

// Institution
app.use('/api', require('./routes/institutionRoutes'));

// Resources
app.use('/api', require('./routes/resourceRoutes'));

// Booking
app.use('/api/booking', require('./routes/sessionBookingRoutes'));

// Payments
app.use('/api/payments', require('./routes/paymentRoutes'));

// Questionnaire
app.use('/api/questionnaire', require('./routes/questionnaireRoutes'));

// Vacations
app.use('/api/vacations', require('./routes/vacationRoutes'));

// Evaluations
app.use('/api/evaluations', require('./routes/evaluations'));

// Forgot Password
app.use('/api/password', require('./routes/forgotPasswordRoutes'));

// Other simple routes
app.use('/api', require('./routes/testRoutes'));

// Static uploads
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ===========================
// 📌 GLOBAL ERROR HANDLER
// ===========================
app.use((err, req, res, next) => {
    console.error('❌ Global Error:', err.message);
    res.status(err.status || 500).json({
        success: false,
        message: err.message
    });
});

// ===========================
// 📌 Handle 404
// ===========================
app.use((req, res) => {
    res.status(404).json({
        success: false,
        message: `Route ${req.url} not found`
    });
});

// ===========================
// 📌 Handle Crashes but DON’T kill server
// ===========================
process.on('uncaughtException', err => {
    console.error('💥 UNCAUGHT EXCEPTION:', err);
});

process.on('unhandledRejection', reason => {
    console.error('💥 UNHANDLED REJECTION:', reason);
});

// ===========================
// 📌 Start Server
// ===========================
let server;

const startServer = async () => {
    try {
        await sequelize.authenticate();
        console.log('✅ Database connected');

        await sequelize.sync();
        console.log('🔄 Models synced');

        const PORT = process.env.PORT || 5000;
        server = app.listen(PORT, () =>
            console.log(`🚀 Server running on http://localhost:${PORT}`)
        );
    } catch (err) {
        console.log('❌ DB Error:', err.message);
        console.log('⏳ Retrying in 5 seconds...');
        setTimeout(startServer, 5000);
    }
};

startServer();
