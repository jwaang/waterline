import { mutation } from "./_generated/server";
import { v } from "convex/values";

export const createUser = mutation({
  args: {
    appleUserId: v.string(),
    settings: v.optional(
      v.object({
        waterEveryNDrinks: v.number(),
        timeRemindersEnabled: v.boolean(),
        timeReminderIntervalMinutes: v.number(),
        warningThreshold: v.number(),
        defaultWaterAmountOz: v.number(),
        units: v.union(v.literal("oz"), v.literal("ml")),
      })
    ),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("users")
      .withIndex("by_appleUserId", (q) => q.eq("appleUserId", args.appleUserId))
      .unique();

    if (existing) {
      return existing._id;
    }

    const settings = args.settings ?? {
      waterEveryNDrinks: 1,
      timeRemindersEnabled: false,
      timeReminderIntervalMinutes: 20,
      warningThreshold: 2,
      defaultWaterAmountOz: 8,
      units: "oz" as const,
    };

    return await ctx.db.insert("users", {
      appleUserId: args.appleUserId,
      createdAt: Date.now(),
      settings,
    });
  },
});

export const upsertSession = mutation({
  args: {
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
    existingId: v.optional(v.id("sessions")),
  },
  handler: async (ctx, args) => {
    const { existingId, ...data } = args;

    if (existingId) {
      await ctx.db.patch(existingId, {
        endTime: data.endTime,
        isActive: data.isActive,
        computedSummary: data.computedSummary,
      });
      return existingId;
    }

    return await ctx.db.insert("sessions", {
      userId: data.userId,
      startTime: data.startTime,
      endTime: data.endTime,
      isActive: data.isActive,
      computedSummary: data.computedSummary,
    });
  },
});

export const addLogEntry = mutation({
  args: {
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
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("logEntries", args);
  },
});

export const deleteLogEntry = mutation({
  args: {
    id: v.id("logEntries"),
  },
  handler: async (ctx, args) => {
    await ctx.db.delete(args.id);
  },
});

export const deleteUser = mutation({
  args: {
    appleUserId: v.string(),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_appleUserId", (q) => q.eq("appleUserId", args.appleUserId))
      .unique();

    if (!user) return;

    // Delete presets
    const presets = await ctx.db
      .query("drinkPresets")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .collect();
    for (const preset of presets) {
      await ctx.db.delete(preset._id);
    }

    // Delete sessions and their log entries
    const sessions = await ctx.db
      .query("sessions")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .collect();
    for (const session of sessions) {
      const entries = await ctx.db
        .query("logEntries")
        .withIndex("by_sessionId", (q) => q.eq("sessionId", session._id))
        .collect();
      for (const entry of entries) {
        await ctx.db.delete(entry._id);
      }
      await ctx.db.delete(session._id);
    }

    // Delete user
    await ctx.db.delete(user._id);
  },
});

export const upsertDrinkPreset = mutation({
  args: {
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
    existingId: v.optional(v.id("drinkPresets")),
  },
  handler: async (ctx, args) => {
    const { existingId, ...data } = args;

    if (existingId) {
      await ctx.db.patch(existingId, {
        name: data.name,
        drinkType: data.drinkType,
        sizeOz: data.sizeOz,
        abv: data.abv,
        standardDrinkEstimate: data.standardDrinkEstimate,
      });
      return existingId;
    }

    return await ctx.db.insert("drinkPresets", data);
  },
});
