import localUnitTest from './LocalUnit.test';
import conversationStoreTest from './ConversationStore.test';
import storeModelMappingTest from './StoreModelMapping.test';

export default function testsuite() {
  localUnitTest();
  conversationStoreTest();
  storeModelMappingTest();
}
