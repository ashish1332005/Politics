const test = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const Member = require('../src/models/Member');
const {
  buildMemberSearchData,
  buildSearchConditions,
  buildFieldSearchConditions,
  canonicalEpic,
  searchExactCandidates,
} = require('../src/utils/memberSearch');

test('indexes Hindi names, joined-name substrings, mobile suffixes and Hindi digits', () => {
  const data = buildMemberSearchData({
    name: 'नेनूराम',
    guardianName: 'प्रतापचन्द',
    mobile: '98765 43210',
    voterId: 'SNEO573606',
    houseNumber: '८',
    village: 'सहाडा',
  });
  assert.ok(data.searchKeys.includes('नेनू'));
  assert.ok(data.searchKeys.includes('राम'));
  assert.ok(data.searchKeys.includes('43210'));
  assert.ok(data.searchKeys.includes('8'));
  assert.ok(data.searchKeys.includes('sne0573606'));
});

test('supports loose Hindi matra matching and multi-field query tokens', () => {
  const conditions = buildSearchConditions('नैनुराम सहाडा');
  assert.equal(conditions.length, 2);
  assert.ok(conditions[0].$or);
  assert.ok(conditions[1].$or);
  assert.deepEqual(conditions[1].$or[0], { searchKeys: 'सहाडा' });
});

test('scopes quick search to voter name, guardian name or EPIC', () => {
  const name = buildFieldSearchConditions('राम', 'name');
  assert.deepEqual(Object.keys(name[0].$or[0]), ['name']);
  assert.deepEqual(Object.keys(name[0].$or[1]), ['surname']);

  const guardian = buildFieldSearchConditions('मोहनलाल', 'guardian');
  assert.equal(guardian[0].$or.length, 1);
  assert.deepEqual(Object.keys(guardian[0].$or[0]), ['guardianName']);

  const epic = buildFieldSearchConditions('ABC1234567', 'epic');
  assert.ok(epic[0].$or.every((condition) => Object.keys(condition)[0] === 'voterId'));
});
test('canonicalizes common OCR mistakes in EPIC numbers', () => {
  assert.equal(canonicalEpic('SNEO5736O6'), 'SNE0573606');
  assert.ok(searchExactCandidates('SNE0573606').includes('sne0573606'));
});

test('member validation automatically refreshes search data', async () => {
  const member = new Member({
    name: 'रामलाल',
    guardianName: 'मोहनलाल',
    voterId: 'ABC1234567',
    booth: new mongoose.Types.ObjectId(),
  });
  await member.validate();
  assert.equal(member.searchVersion, 1);
  assert.ok(member.searchKeys.includes('राम'));
  assert.ok(member.searchKeys.includes('लाल'));
});
