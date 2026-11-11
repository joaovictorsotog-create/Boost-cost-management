import { describe, expect, it } from "vitest";
import { decimalInput } from "./costing";

describe("costing decimal input", () => {
  it.each(["10", "1.25", "0.500", "0"])("accepts %s", value => {
    expect(decimalInput.safeParse(value).success).toBe(true);
  });

  it.each(["1.2345", "-1", "-0.5", "", ".5", "1.", "1,25", " 1"])(
    "rejects %s",
    value => {
      expect(decimalInput.safeParse(value).success).toBe(false);
    }
  );
});
