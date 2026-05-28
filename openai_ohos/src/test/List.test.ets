import localUnitTest from './LocalUnit.test';
import modelsUnitTest from './Models.test';
import returnValuesUnitTest from './ReturnValues.test';

export default function testsuite() {
  localUnitTest();
  modelsUnitTest();
  returnValuesUnitTest();
}
