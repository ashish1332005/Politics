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
  assert.ok(conditions[1].$or[0].searchKeys.$in.includes('सहाडा'));
});

test('scopes quick search to voter name, guardian name or EPIC', () => {
  const name = buildFieldSearchConditions('राम', 'name');
  assert.deepEqual(Object.keys(name[0].$or[0]), ['searchNameKeys']);
  assert.ok(name[0].$or.some((condition) => condition.name));
  assert.ok(name[0].$or.some((condition) => condition.surname));

  const guardian = buildFieldSearchConditions('मोहनलाल', 'guardian');
  assert.deepEqual(Object.keys(guardian[0].$or[0]), ['searchGuardianKeys']);
  assert.ok(guardian[0].$or.some((condition) => condition.guardianName));

  const epic = buildFieldSearchConditions('ABC1234567', 'epic');
  assert.deepEqual(Object.keys(epic[0].$or[0]), ['searchEpicKeys']);
  assert.ok(epic[0].$or.some((condition) => condition.voterId));
});

test('matches joined names and one-character typing mistakes within selected fields', () => {
  const data = buildMemberSearchData({
    name: 'Arjun Lal',
    guardianName: 'Mohan Lal',
    voterId: 'ABC1234567',
    mobile: '9876543210',
    houseNumber: '1234',
  });
  assert.ok(data.searchNameKeys.includes('arjunlal'));
  assert.ok(data.searchNameKeys.includes('arjnlal'));

  const typoName = buildFieldSearchConditions('arjnlal', 'name');
  assert.ok(typoName[0].$or[0].searchNameKeys.$in.includes('arjnlal'));
  const typoGuardian = buildFieldSearchConditions('mohnlal', 'guardian');
  assert.ok(typoGuardian[0].$or[0].searchGuardianKeys.$in.length > 0);
  const typoEpic = buildFieldSearchConditions('ABC1234568', 'epic');
  assert.ok(typoEpic[0].$or[0].searchEpicKeys.$in.length > 0);
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
  assert.equal(member.searchVersion, 2);
  assert.ok(member.searchKeys.includes('राम'));
  assert.ok(member.searchKeys.includes('लाल'));
});
