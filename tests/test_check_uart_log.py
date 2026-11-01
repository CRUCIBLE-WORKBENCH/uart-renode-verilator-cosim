"""Unit tests for scripts/check_uart_log.py: python3 -m unittest discover -s tests"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import check_uart_log as c  # noqa: E402


def passing_log(values=None):
    values = values or [v for _, v in c.EXPECTED]
    lines = ["12:00:00.0000 [INFO] System bus created.",
             "Renode at 0.000000000s: Connection status after connect: Connected"]
    for (label, _), value in zip(c.EXPECTED, values):
        lines += [label, c.show(value)]
    lines += [c.DONE_MARKER, "Renode is quitting"]
    return "\n".join(lines) + "\n"


class CheckUartLogTests(unittest.TestCase):
    def test_measured_run_passes(self):
        self.assertEqual(c.problems(passing_log()), [])

    def test_changed_rx_byte_is_rejected(self):
        values = [v for _, v in c.EXPECTED]
        values[[l for l, _ in c.EXPECTED].index("DATA rx 'Z'")] = 0x0001005B
        self.assertTrue(c.problems(passing_log(values)))

    def test_flipped_interrupt_line_is_rejected(self):
        values = [v for _, v in c.EXPECTED]
        values[[l for l, _ in c.EXPECTED].index("IRQ rx pending")] = False
        self.assertTrue(c.problems(passing_log(values)))

    def test_byte_that_skips_the_wire_is_rejected(self):
        # A model that reflected TX straight into the RX register would show
        # the byte before any simulated time passed.
        values = [v for _, v in c.EXPECTED]
        values[[l for l, _ in c.EXPECTED].index("DATA 'A' still on the wire")] = 0x00010041
        self.assertTrue(c.problems(passing_log(values)))

    def test_irq_state_is_not_read_as_a_number(self):
        values = [v for _, v in c.EXPECTED]
        values[[l for l, _ in c.EXPECTED].index("IRQ tx empty")] = 1
        self.assertTrue(c.problems(passing_log(values)))

    def test_wrong_expectation_is_rejected(self):
        expected = c.with_overrides(["DATA rx 'Z'=0x0001005B"])
        self.assertTrue(c.problems(passing_log(), expected))

    def test_model_load_error_is_rejected_even_with_good_values(self):
        log = passing_log() + "12:00:01 [ERROR] cosimulation_connection: Error starting cosimulated peripheral!\n"
        self.assertIn("Renode reported", c.problems(log)[0])

    def test_monitor_error_is_rejected(self):
        log = passing_log() + "There was an error executing command 'uart SimulationFilePathLinux $model': \n"
        self.assertTrue(c.problems(log))

    def test_model_assertion_is_rejected(self):
        log = passing_log() + ("[0.006000080s] %Error: renode_pkg.sv:127: Assertion failed in "
                               "TOP.renode_pkg.renode_connection.fatal_error: Error! Unexpected channel disconnection\n")
        self.assertTrue(c.problems(log))

    def test_operation_timeout_is_rejected(self):
        log = passing_log() + "12:00:01 [WARNING] uart: Operation timeout\n"
        self.assertTrue(c.problems(log))

    def test_truncated_run_is_rejected(self):
        log = passing_log().replace(c.DONE_MARKER + "\n", "")
        self.assertIn("script did not reach " + c.DONE_MARKER, c.problems(log))

    def test_missing_reads_are_rejected(self):
        log = "\n".join(passing_log().splitlines()[:6] + [c.DONE_MARKER])
        self.assertTrue(any(p.startswith("missing read") for p in c.problems(log)))

    def test_unlabelled_hex_is_not_counted(self):
        log = "0x00200000\n" + passing_log()
        self.assertEqual(c.problems(log), [])

    def test_reordered_reads_are_rejected(self):
        lines = passing_log().splitlines()
        a, b = lines.index("DATA rx 'A'"), lines.index("DATA rx 'Z'")
        lines[a:a + 2], lines[b:b + 2] = lines[b:b + 2], lines[a:a + 2]
        self.assertTrue(c.problems("\n".join(lines)))

    def test_unknown_override_label_exits(self):
        with self.assertRaises(SystemExit):
            c.with_overrides(["DATA rx 'Q'=0x1"])

    def test_override_of_the_wrong_kind_exits(self):
        with self.assertRaises(SystemExit):
            c.with_overrides(["IRQ rx pending=0x1"])
        self.assertEqual(dict(c.with_overrides(["IRQ rx pending=False"]))["IRQ rx pending"], False)


if __name__ == "__main__":
    unittest.main()
