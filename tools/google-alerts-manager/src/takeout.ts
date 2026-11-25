import { readFile, stat } from "node:fs/promises";
import { crc32 } from "node:zlib";
import type { Entry } from "yauzl";
import yauzl from "yauzl";
import {
  bytesHash,
  duplicateGroups,
  identify,
  takeoutSchema,
} from "./model.ts";

const TARGET = "Takeout/Alerts/ALERTS-SUBSCRIPTIONS.JSON";
export const MAX_JSON = 8 * 1024 * 1024;
const MAX_ARCHIVE = 128 * 1024 * 1024;
function readZip(path: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    yauzl.open(
      path,
      { lazyEntries: true, validateEntrySizes: true, strictFileNames: true },
      (error, zip) => {
        if (error || !zip) {
          reject(new Error("Invalid ZIP archive"));
          return;
        }
        let payload: Buffer | undefined;
        let entries = 0;
        let done = false;
        const fail = () => {
          if (!done) {
            done = true;
            zip.close();
            reject(new Error("Unsafe or unsupported ZIP archive"));
          }
        };
        zip.on("error", fail);
        zip.on("end", () => {
          if (done) return;
          done = true;
          if (!payload)
            reject(new Error("Takeout subscriptions entry is missing"));
          else resolve(payload);
        });
        zip.on("entry", (entry: Entry) => {
          const parts = entry.fileName.split("/");
          const unixType = (entry.externalFileAttributes >>> 16) & 0o170000;
          if (
            ++entries > 10000 ||
            entry.fileName.startsWith("/") ||
            parts.includes("..") ||
            entry.fileName.includes("\\") ||
            unixType === 0o120000 ||
            entry.generalPurposeBitFlag & 1
          ) {
            fail();
            return;
          }
          if (entry.fileName !== TARGET) {
            zip.readEntry();
            return;
          }
          if (
            payload ||
            entry.uncompressedSize > MAX_JSON ||
            ![0, 8].includes(entry.compressionMethod)
          ) {
            fail();
            return;
          }
          zip.openReadStream(entry, (err, stream) => {
            if (err || !stream) {
              fail();
              return;
            }
            let size = 0;
            const chunks: Buffer[] = [];
            stream.on("error", fail);
            stream.on("data", (chunk: Buffer) => {
              size += chunk.length;
              if (size > MAX_JSON) {
                stream.destroy();
                fail();
                return;
              }
              chunks.push(chunk);
            });
            stream.on("end", () => {
              if (done) return;
              const bytes = Buffer.concat(chunks);
              if (crc32(bytes) !== entry.crc32) {
                fail();
                return;
              }
              payload = bytes;
              zip.readEntry();
            });
          });
        });
        zip.readEntry();
      },
    );
  });
}
export async function inspectTakeout(path: string) {
  const info = await stat(path);
  if (!info.isFile() || info.size > MAX_ARCHIVE)
    throw new Error("Import exceeds file limits");
  const signature = await readFile(path).then((b) => b.subarray(0, 4));
  const payload =
    signature[0] === 0x50 && signature[1] === 0x4b
      ? await readZip(path)
      : await readFile(path);
  if (payload.length > MAX_JSON)
    throw new Error("Subscriptions JSON exceeds size limit");
  let document;
  try {
    document = takeoutSchema.parse(
      JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(payload)),
    );
  } catch {
    throw new Error("Invalid Takeout subscriptions schema (values withheld)");
  }
  const records = identify(document.subscriptions);
  return {
    digest: bytesHash(payload),
    payload,
    records,
    duplicates: duplicateGroups(records),
  };
}
