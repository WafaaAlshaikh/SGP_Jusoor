    const crypto = require('crypto');
    const nodemailer = require('nodemailer');
    const bcrypt = require('bcrypt');
    const User = require('../model/User');
    require('dotenv').config();

    // كائن لتخزين الأكواد مؤقتاً (يفضل لاحقاً حفظها في DB)
    const resetCodes = new Map();

    const sendResetCode = async (req, res) => {
    const { email } = req.body;

    if (!email) return res.status(400).json({ message: 'Email is required' });

    try {
        const user = await User.findOne({ where: { email } });
        if (!user) return res.status(404).json({ message: 'No account found with this email' });

        // توليد كود عشوائي من 6 أرقام
        const resetCode = Math.floor(100000 + Math.random() * 900000).toString();

        // تخزين الكود مؤقتاً لمدة 10 دقائق
        resetCodes.set(email, {
        code: resetCode,
        expiresAt: Date.now() + 10 * 60 * 1000
        });

        // إعداد الإيميل
        const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
            user: process.env.EMAIL_USER,
            pass: process.env.EMAIL_PASS
        }
        });

        const mailOptions = {
        from: process.env.EMAIL_USER,
        to: email,
        subject: 'Password Reset Code',
        text: `Your password reset code is: ${resetCode}`
        };

        await transporter.sendMail(mailOptions);

        res.status(200).json({ message: 'Reset code sent to your email' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
    };

    const verifyResetCode = (req, res) => {
    const { email, code } = req.body;

    const entry = resetCodes.get(email);
    if (!entry) return res.status(400).json({ message: 'No reset request found for this email' });

    if (entry.expiresAt < Date.now()) {
        resetCodes.delete(email);
        return res.status(400).json({ message: 'Code expired' });
    }

    if (entry.code !== code) {
        return res.status(400).json({ message: 'Invalid code' });
    }

    res.status(200).json({ message: 'Code verified successfully' });
    };

    const resetPassword = async (req, res) => {
    const { email, code, newPassword } = req.body;

    const entry = resetCodes.get(email);
    if (!entry) return res.status(400).json({ message: 'No reset request found for this email' });
    if (entry.code !== code) return res.status(400).json({ message: 'Invalid code' });

    try {
        const hashedPassword = await bcrypt.hash(newPassword, 10);
        await User.update({ password: hashedPassword }, { where: { email } });

        resetCodes.delete(email);

        res.status(200).json({ message: 'Password reset successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
    };

    module.exports = { sendResetCode, verifyResetCode, resetPassword };
