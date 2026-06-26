const mongoose = require('mongoose');

const MessageSenderSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  displayNumber: { type: String, required: true, trim: true },
  phoneNumberId: {
    type: String,
    trim: true,
    default: '',
    required() { return this.provider === 'whatsapp_cloud'; },
  },
  businessAccountId: { type: String, trim: true, default: '' },
  provider: {
    type: String,
    enum: ['whatsapp_web', 'whatsapp_cloud'],
    default: 'whatsapp_web',
  },
  sessionId: { type: String, trim: true, default: '' },
  connectionStatus: {
    type: String,
    enum: ['disconnected', 'starting', 'qr_ready', 'authenticated', 'connected', 'failed'],
    default: 'disconnected',
  },
  qrCode: { type: String, default: '' },
  connectedNumber: { type: String, trim: true, default: '' },
  lastError: { type: String, default: '' },
  lastSeenAt: Date,
  active: { type: Boolean, default: true },
  isDefault: { type: Boolean, default: false },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true });

MessageSenderSchema.index({ phoneNumberId: 1 }, { unique: true, sparse: true });
MessageSenderSchema.index({ sessionId: 1 }, { unique: true, sparse: true });

module.exports = mongoose.model('MessageSender', MessageSenderSchema);
