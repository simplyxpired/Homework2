import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

let environment;
let ownerDb;
let otherDb;
let signedOutDb;
let messageId;

function newMessage() {
  return {
    authorUid: 'rules-test-owner',
    authorName: 'Test Owner',
    text: 'Rules unit test message',
    createdAt: serverTimestamp(),
  };
}

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'homework2-11',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });

  ownerDb = environment.authenticatedContext('rules-test-owner').firestore();
  otherDb = environment.authenticatedContext('rules-test-other').firestore();
  signedOutDb = environment.unauthenticatedContext().firestore();

  const message = doc(collection(ownerDb, 'messages'));
  await assertSucceeds(setDoc(message, newMessage()));
  messageId = message.id;
});

after(async () => {
  if (!environment) return;

  try {
    if (messageId) {
      await deleteDoc(doc(ownerDb, 'messages', messageId));
    }
  } finally {
    await environment.cleanup();
  }
});

test('Signed-out user cannot read a message', async () => {
  await assertFails(getDoc(doc(signedOutDb, 'messages', messageId)));
});

test('Another user cannot edit or delete the message', async () => {
  const message = doc(otherDb, 'messages', messageId);

  await assertFails(updateDoc(message, {
    text: 'Unauthorized edit',
    editedAt: serverTimestamp(),
  }));

  await assertFails(deleteDoc(message));
});

test('A user cannot create a message with another author UID', async () => {
  const message = doc(collection(otherDb, 'messages'));

  await assertFails(setDoc(message, newMessage()));
});

test('The author can create, read, edit, and delete a message', async () => {
  const message = doc(collection(ownerDb, 'messages'));

  await assertSucceeds(setDoc(message, newMessage()));

  const created = await assertSucceeds(getDoc(message));
  assert.equal(created.data().text, 'Rules unit test message');

  await assertSucceeds(updateDoc(message, {
    text: 'Updated by the author',
    editedAt: serverTimestamp(),
  }));

  const edited = await assertSucceeds(getDoc(message));
  assert.equal(edited.data().text, 'Updated by the author');
  assert.ok(edited.data().editedAt);

  await assertSucceeds(deleteDoc(message));

  const deleted = await assertSucceeds(getDoc(message));
  assert.equal(deleted.exists(), false);
});