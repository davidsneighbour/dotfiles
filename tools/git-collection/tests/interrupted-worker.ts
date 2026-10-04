import { collect } from "../src/collector.ts";
import { openDatabase } from "../src/database.ts";

const [database, repository] = process.argv.slice(2);
if (!database || !repository)
  throw new Error("Test worker requires database and repository paths.");
const db = openDatabase(database, true);
db.function("pause_write", () => {
  process.stdout.write("WRITE_IN_PROGRESS\n");
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0);
  return 0;
});
db.exec(
  "CREATE TEMP TRIGGER pause_import AFTER INSERT ON commits BEGIN SELECT pause_write(); END;",
);
try {
  await collect(db, repository);
} finally {
  db.close();
}
