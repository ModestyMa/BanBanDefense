import localUnitTest from './LocalUnit.test';
import dateUtilsTest from './DateUtils.test';

export default function testsuite() {
  localUnitTest();
  dateUtilsTest();
}
