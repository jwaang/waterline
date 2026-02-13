import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const verifyAndCreateUser = mutation({
  args: {
    appleIdentityToken: v.string(),
    appleUserId: v.string(),
    email: v.optional(v.string()),
    fullName: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Look up existing user by Apple User ID
    const existing = await ctx.db
      .query("users")
      .withIndex("by_appleUserId", (q) =>
        q.eq("appleUserId", args.appleUserId)
      )
      .unique();

    if (existing) {
      return { userId: existing._id, isNewUser: false };
    }

    // Create new user with default settings
    const userId = await ctx.db.insert("users", {
      appleUserId: args.appleUserId,
      createdAt: Date.now(),
      settings: {
        waterEveryNDrinks: 1,
        timeRemindersEnabled: false,
        timeReminderIntervalMinutes: 20,
        warningThreshold: 2,
        defaultWaterAmountOz: 8,
        units: "oz",
      },
    });

    return { userId, isNewUser: true };
  },
});

export const getUserByAppleId = query({
  args: {
    appleUserId: v.string(),
  },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("users")
      .withIndex("by_appleUserId", (q) =>
        q.eq("appleUserId", args.appleUserId)
      )
      .unique();
  },
});
