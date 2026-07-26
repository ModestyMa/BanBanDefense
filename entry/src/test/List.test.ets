import localUnitTest from './LocalUnit.test';
import dateUtilsTest from './DateUtils.test';
import moneyUtilsTest from './MoneyUtils.test';
import reportUtilsTest from './ReportUtils.test';

export default function testsuite() {
  localUnitTest();
  dateUtilsTest();
  moneyUtilsTest();
  reportUtilsTest();
}
