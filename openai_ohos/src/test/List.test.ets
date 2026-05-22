import localUnitTest from './LocalUnit.test';
import modelsUnitTest from './Models.test';

export default function testsuite() {
  localUnitTest();
  modelsUnitTest();
}
