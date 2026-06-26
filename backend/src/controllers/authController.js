const { validationResult } = require('express-validator');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const publicUser = (user) => {
  const obj = user.toObject ? user.toObject() : user;
  delete obj.password;
  return obj;
};

const sign = (user) => jwt.sign(
  { user: { id: user._id, role: user.role } },
  process.env.JWT_SECRET || 'change-this-secret',
  { expiresIn: process.env.JWT_EXPIRES_IN || '7d' },
);

exports.register = async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    const { name, email, password, role = 'booth', assignedWard, assignedBooth, phone, permissions } = req.body;

    if (role === 'admin' && req.currentUser && req.currentUser.role !== 'admin') {
      return res.status(403).json({ message: 'Only admin can create admin users' });
    }
    if (role === 'booth' && !assignedBooth) {
      return res.status(400).json({ message: 'Booth user requires assignedBooth' });
    }
    if (role === 'ward_head' && !assignedWard) {
      return res.status(400).json({ message: 'Ward head requires assignedWard' });
    }

    const exists = await User.findOne({ email });
    if (exists) return res.status(409).json({ message: 'User already exists' });

    const hash = await bcrypt.hash(password, 12);
    const user = await User.create({ name, email, password: hash, role, assignedWard, assignedBooth, phone, permissions });
    const populated = await User.findById(user._id).populate('assignedWard assignedBooth');
    res.status(201).json({ token: sign(user), user: publicUser(populated) });
  } catch (error) {
    next(error);
  }
};

exports.login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email }).select('+password').populate('assignedWard assignedBooth');
    if (!user || !user.active) return res.status(400).json({ message: 'Invalid credentials' });
    const ok = await bcrypt.compare(password, user.password);
    if (!ok) return res.status(400).json({ message: 'Invalid credentials' });
    res.json({ token: sign(user), user: publicUser(user) });
  } catch (error) {
    next(error);
  }
};

exports.me = async (req, res, next) => {
  try {
    const user = await User.findById(req.currentUser._id).populate('assignedWard assignedBooth');
    res.json(publicUser(user));
  } catch (error) {
    next(error);
  }
};

exports.listUsers = async (req, res, next) => {
  try {
    const users = await User.find().populate('assignedWard assignedBooth').sort({ createdAt: -1 });
    res.json(users.map(publicUser));
  } catch (error) {
    next(error);
  }
};

exports.updateUser = async (req, res, next) => {
  try {
    const data = { ...req.body };
    if (data.password) data.password = await bcrypt.hash(data.password, 12);
    const user = await User.findByIdAndUpdate(req.params.id, data, { new: true }).populate('assignedWard assignedBooth');
    if (!user) return res.status(404).json({ message: 'User not found' });
    res.json(publicUser(user));
  } catch (error) {
    next(error);
  }
};
