const mongoose = require('mongoose');

const FamilyMemberSchema = new mongoose.Schema({
  name: { type: String, trim: true },
  relation: { type: String, trim: true },
  mobile: { type: String, trim: true },
  dob: Date,
  occupation: String,
  education: String,
}, { _id: true });

const VisitSchema = new mongoose.Schema({
  date: { type: Date, default: Date.now },
  outcome: String,
  notes: String,
  visitedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { _id: true });

const AttendanceSchema = new mongoose.Schema({
  meetingTitle: String,
  date: Date,
  status: { type: String, enum: ['attended', 'absent', 'invited'], default: 'invited' },
}, { _id: true });

const FollowUpSchema = new mongoose.Schema({
  title: { type: String, required: true, trim: true },
  dueAt: { type: Date, required: true },
  type: { type: String, enum: ['call', 'whatsapp', 'visit', 'meeting', 'other'], default: 'call' },
  priority: { type: String, enum: ['low', 'medium', 'high'], default: 'medium' },
  status: { type: String, enum: ['pending', 'done', 'cancelled'], default: 'pending' },
  notes: String,
  outcome: String,
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  completedAt: Date,
}, { timestamps: true });
const MemberSchema = new mongoose.Schema({
  photo: String,
  qrCode: String,
  name: { type: String, required: true, trim: true },
  surname: { type: String, trim: true },
  mobile: { type: String, trim: true, default: '' },
  altMobile: { type: String, trim: true },
  dob: Date,
  estimatedDob: Date,
  age: Number,
  anniversary: Date,
  gender: { type: String, enum: ['male', 'female', 'other', ''], default: '' },
  address: { type: String, trim: true },
  houseNumber: { type: String, trim: true },
  location: { type: String, trim: true },
  area: { type: mongoose.Schema.Types.ObjectId, ref: 'Area' },
  tehsil: { type: String, trim: true },
  gramPanchayat: { type: String, trim: true },
  village: { type: String, trim: true },
  municipality: { type: String, trim: true },
  caste: { type: String, trim: true },
  subCaste: { type: String, trim: true },
  organizationPost: { type: String, trim: true },
  organizationLevel: { type: String, trim: true },
  influenceLevel: { type: String, enum: ['high', 'medium', 'normal', ''], default: '' },
  whatsappOptIn: { type: Boolean, default: true },
  assemblyNumber: String,
  assemblyName: String,
  partNumber: String,
  sectionNumber: String,
  sectionName: String,
  voterSerial: String,
  voterId: {
    type: String,
    required: [true, 'EPIC number is required.'],
    unique: true,
    uppercase: true,
    trim: true,
    immutable: true,
  },
  guardianName: String,
  relationType: { type: String, enum: ['father', 'husband', 'mother', 'other', ''], default: '' },
  geo: {
    lat: Number,
    lng: Number,
  },
  ward: { type: mongoose.Schema.Types.ObjectId, ref: 'Ward' },
  booth: { type: mongoose.Schema.Types.ObjectId, ref: 'Booth', required: true },
  family: [FamilyMemberSchema],
  occupation: String,
  education: String,
  party: { type: mongoose.Schema.Types.ObjectId, ref: 'Party' },
  supportLevel: {
    type: String,
    enum: ['supporter', 'neutral', 'opposite', 'undecided'],
    default: 'undecided',
  },
  notes: String,
  extraDetails: [{
    label: { type: String, trim: true },
    value: { type: String, trim: true },
  }],
  sourceDocument: {
    type: { type: String, enum: ['manual', 'excel', 'csv', 'pdf'], default: 'manual' },
    file: String,
    rawText: String,
    imageExtractionStatus: String,
  },
  localIssues: [{
    title: String,
    status: { type: String, enum: ['open', 'in_progress', 'resolved'], default: 'open' },
    priority: { type: String, enum: ['low', 'medium', 'high'], default: 'medium' },
    createdAt: { type: Date, default: Date.now },
  }],
  tasks: [{
    title: String,
    dueDate: Date,
    assignedTo: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    status: { type: String, enum: ['pending', 'done'], default: 'pending' },
  }],
  visits: [VisitSchema],
  meetingAttendance: [AttendanceSchema],
  verificationStatus: {
    type: String,
    enum: ['pending', 'verified', 'needs_review', 'duplicate'],
    default: 'pending',
  },
  duplicateWarnings: [{
    field: String,
    member: { type: mongoose.Schema.Types.ObjectId, ref: 'Member' },
    value: String,
  }],
  lastContact: Date,
  followUps: [FollowUpSchema],
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true });

MemberSchema.index({ mobile: 1 });
MemberSchema.index({ voterId: 1 }, { unique: true });
MemberSchema.index({ address: 'text', name: 'text', surname: 'text', location: 'text', sectionName: 'text', assemblyName: 'text', voterId: 'text', guardianName: 'text' });
MemberSchema.index({ booth: 1, supportLevel: 1 });
MemberSchema.index({ assemblyNumber: 1, partNumber: 1, sectionName: 1 });
MemberSchema.index({ area: 1, organizationPost: 1, caste: 1 });

module.exports = mongoose.model('Member', MemberSchema);



