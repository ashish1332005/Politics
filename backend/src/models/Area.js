const mongoose = require('mongoose');

const AreaSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  code: { type: String, trim: true, default: '' },
  type: {
    type: String,
    required: true,
    enum: ['assembly', 'tehsil', 'gram_panchayat', 'municipality', 'village', 'ward'],
  },
  parent: { type: mongoose.Schema.Types.ObjectId, ref: 'Area', default: null },
  assemblyNumber: { type: String, trim: true, default: '' },
  district: { type: String, trim: true, default: '' },
  active: { type: Boolean, default: true },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true });

AreaSchema.index({ parent: 1, type: 1, name: 1 }, { unique: true });

module.exports = mongoose.model('Area', AreaSchema);
