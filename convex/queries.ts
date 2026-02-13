import { query } from "./_generated/server";
import { v } from "convex/values";

export const getActiveSession = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("sessions")
      .withIndex("by_userId_isActive", (q) =>
        q.eq("userId", args.userId).eq("isActive", true)
      )
      .unique();
  },
});

export const getSessionLogs = query({
  args: {
    sessionId: v.id("sessions"),
  },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("logEntries")
      .withIndex("by_sessionId_timestamp", (q) =>
        q.eq("sessionId", args.sessionId)
      )
      .collect();
  },
});

export const getUserPresets = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("drinkPresets")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
  },
});
