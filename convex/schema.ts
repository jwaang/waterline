import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    appleUserId: v.string(),
    createdAt: v.number(),
    settings: v.object({
      waterEveryNDrinks: v.number(),
      timeRemindersEnabled: v.boolean(),
      timeReminderIntervalMinutes: v.number(),
      warningThreshold: v.number(),
      defaultWaterAmountOz: v.number(),
      units: v.union(v.literal("oz"), v.literal("ml")),
    }),
  }).index("by_appleUserId", ["appleUserId"]),

  sessions: defineTable({
    userId: v.id("users"),
    startTime: v.number(),
    endTime: v.optional(v.number()),
    isActive: v.boolean(),
    computedSummary: v.optional(
      v.object({
        totalDrinks: v.number(),
        totalWater: v.number(),
        totalStandardDrinks: v.number(),
        durationSeconds: v.number(),
        pacingAdherence: v.number(),
        finalWaterlineValue: v.number(),
      })
    ),
  })
    .index("by_userId", ["userId"])
    .index("by_userId_isActive", ["userId", "isActive"]),

  logEntries: defineTable({
    sessionId: v.id("sessions"),
    timestamp: v.number(),
    type: v.union(v.literal("alcohol"), v.literal("water")),
    alcoholMeta: v.optional(
      v.object({
        drinkType: v.union(
          v.literal("beer"),
          v.literal("wine"),
          v.literal("liquor"),
          v.literal("cocktail")
        ),
        sizeOz: v.number(),
        abv: v.optional(v.number()),
        standardDrinkEstimate: v.number(),
        presetId: v.optional(v.string()),
      })
    ),
    waterMeta: v.optional(
      v.object({
        amountOz: v.number(),
      })
    ),
    source: v.union(
      v.literal("phone"),
      v.literal("watch"),
      v.literal("widget"),
      v.literal("liveActivity")
    ),
  })
    .index("by_sessionId", ["sessionId"])
    .index("by_sessionId_timestamp", ["sessionId", "timestamp"]),

  drinkPresets: defineTable({
    userId: v.id("users"),
    name: v.string(),
    drinkType: v.union(
      v.literal("beer"),
      v.literal("wine"),
      v.literal("liquor"),
      v.literal("cocktail")
    ),
    sizeOz: v.number(),
    abv: v.optional(v.number()),
    standardDrinkEstimate: v.number(),
  }).index("by_userId", ["userId"]),
});
