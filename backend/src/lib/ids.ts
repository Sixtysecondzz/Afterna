import { randomUUID } from "node:crypto";

export function id(): string {
  return randomUUID();
}

export function yearMonth(d = new Date()): number {
  return d.getUTCFullYear() * 100 + (d.getUTCMonth() + 1);
}
