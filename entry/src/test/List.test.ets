import localUnitTest from './LocalUnit.test';
import conversationStoreTest from './ConversationStore.test';

export default function testsuite() {
  localUnitTest();
  conversationStoreTest();
}
