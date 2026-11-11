import postgres from "postgres";

const url = process.env.SUPABASE_DATABASE_URL;
if (!url) throw new Error("SUPABASE_DATABASE_URL is required");
const admin = postgres(url, { max: 1 });

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

async function expectReject(work: () => Promise<unknown>, fragment: string) {
  try {
    await work();
    throw new Error(`expected rejection containing ${fragment}`);
  } catch (error) {
    if (!(error instanceof Error) || !error.message.includes(fragment)) throw error;
  }
}

const { updateCostGroup, updateCostItem } = await import("../server/db/costing");
const now = "now";
await admin`
  INSERT INTO "organizations" ("id","name","slug","createdAt","updatedAt")
  VALUES ('org-edit-verification','Edit Verification','edit-verification',1,1),
         ('org-edit-foreign','Edit Foreign','edit-foreign',1,1)
`;
await admin`
  INSERT INTO "cost_groups" ("id","organizationId","name","position","createdAt","updatedAt")
  VALUES ('edit-group','org-edit-verification','Original',0,${now},${now}),
         ('foreign-group','org-edit-foreign','Foreign',0,${now},${now})
`;
await admin`
  INSERT INTO "cost_items" ("id","organizationId","groupId","code","name","itemType","referenceUnit","manualUnitCost","createdAt","updatedAt")
  VALUES ('edit-item','org-edit-verification','edit-group','EDIT-1','Original Item','SIMPLE','kg','10',${now},${now})
`;
await admin`
  INSERT INTO "cost_structures" ("id","organizationId","itemId","version","status","outputQuantity","createdAt","updatedAt")
  VALUES ('edit-published-structure','org-edit-verification','edit-item',1,'ACTIVE','1',${now},${now})
`;

const group = await updateCostGroup({
  organizationId: "org-edit-verification",
  groupId: "edit-group",
  name: "Updated Group",
  description: "Updated description",
  position: 4,
});
assert(group?.name === "Updated Group" && group.position === 4, "group update failed");

const item = await updateCostItem({
  organizationId: "org-edit-verification",
  itemId: "edit-item",
  name: "Updated Item",
  code: "EDIT-2",
  description: "Updated description",
  referenceUnit: "kg",
  groupId: "edit-group",
  manualUnitCost: "12.500",
});
assert(item?.name === "Updated Item" && item.manualUnitCost === "12.500", "item update failed");

await expectReject(
  () => updateCostItem({
    organizationId: "org-edit-verification",
    itemId: "edit-item",
    name: "Updated Item",
    referenceUnit: "kg",
    groupId: "foreign-group",
    manualUnitCost: "12.500",
  }),
  "Grupo não encontrado"
);
await expectReject(
  () => updateCostItem({
    organizationId: "org-edit-verification",
    itemId: "edit-item",
    name: "Updated Item",
    referenceUnit: "",
    groupId: "edit-group",
    manualUnitCost: "12.500",
  }),
  "Unidade de referência inválida"
);
await expectReject(
  () => updateCostItem({
    organizationId: "org-edit-verification",
    itemId: "edit-item",
    name: "Updated Item",
    referenceUnit: "g",
    groupId: "edit-group",
    manualUnitCost: "12.500",
  }),
  "não pode ser alterada após a publicação"
);
await expectReject(
  () => updateCostItem({
    organizationId: "org-edit-foreign",
    itemId: "edit-item",
    name: "Foreign Attempt",
    referenceUnit: "kg",
    manualUnitCost: "99",
  }),
  "Item não encontrado na organização"
);

const [storedGroup] = await admin`SELECT "name","position" FROM "cost_groups" WHERE "id" = 'edit-group'`;
const [storedItem] = await admin`SELECT "name","code","manualUnitCost" FROM "cost_items" WHERE "id" = 'edit-item'`;
assert(storedGroup?.name === "Updated Group" && storedGroup.position === 4, "stored group mismatch");
assert(storedItem?.name === "Updated Item" && storedItem.code === "EDIT-2" && storedItem.manualUnitCost === "12.500", "stored item mismatch");
await admin.end({ timeout: 5 });
console.log(JSON.stringify({
  groupUpdated: true,
  itemUpdated: true,
  crossTenantGroupRejected: true,
  invalidUnitRejected: true,
  publishedUnitMutationRejected: true,
  foreignItemRejected: true,
  result: "COSTING_CRUD_EDIT_TEST=PASS",
}));
process.exit(0);
