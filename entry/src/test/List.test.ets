import localUnitTest from './LocalUnit.test';
import tavernRuntimeTest from './TavernRuntime.test';

export default function testsuite() {
  localUnitTest();
  tavernRuntimeTest();
}
