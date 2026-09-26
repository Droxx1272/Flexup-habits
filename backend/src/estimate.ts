import Anthropic from "@anthropic-ai/sdk";

/**
 * Itemised calorie + macro estimation from a meal photo.
 *
 * This used to run inside the iOS app with an on-device key. It lives here
 * now so the key stays on the server, and so the prompt can be improved
 * without shipping an app update.
 *
 * Two inputs beyond the photo carry most of the accuracy: the person's
 * cooking context (Western databases badly misjudge regional dishes) and a
 * free-text correction for what the camera can't see — the spoon of ghee,
 * the deep-frying, the dressing already mixed in.
 */

/** Haiku 4.5: ~$0.004–0.005 per photo, good enough for calorie awareness. */
export const MODEL = "claude-haiku-4-5";

export interface MealItem {
  name: string;
  calories: number;
  portion: string;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  fiber_g: number;
  sugar_g: number;
  sodium_mg: number;
}

export interface MealEstimate {
  meal_name: string;
  items: MealItem[];
  confidence: "low" | "medium" | "high";
  notes: string;
}

export type ImageMediaType = "image/jpeg" | "image/png" | "image/webp";

export class EstimateRefusedError extends Error {}
export class EstimateMalformedError extends Error {}

const outputSchema = {
  type: "object",
  properties: {
    meal_name: {
      type: "string",
      description: "Short name for the whole meal, max 5 words. Use the dish's real name where you can identify it.",
    },
    items: {
      type: "array",
      description: "Each distinct component of the meal, listed separately.",
      items: {
        type: "object",
        properties: {
          name: { type: "string", description: "Component name, e.g. 'Dal', 'Rice', 'Roti'" },
          calories: { type: "integer", description: "Calories for the portion described" },
          portion: { type: "string", description: "The portion you estimated, e.g. '1 cup', '2 pieces', '150 g'" },
          protein_g: { type: "number", description: "Protein in grams for this portion" },
          carbs_g: { type: "number", description: "Total carbohydrate in grams for this portion" },
          fat_g: { type: "number", description: "Fat in grams for this portion, including cooking fat" },
          fiber_g: { type: "number", description: "Dietary fibre in grams for this portion" },
          sugar_g: { type: "number", description: "Sugars in grams for this portion" },
          sodium_mg: { type: "number", description: "Sodium in milligrams for this portion" },
        },
        required: ["name", "calories", "portion", "protein_g", "carbs_g", "fat_g", "fiber_g", "sugar_g", "sodium_mg"],
        additionalProperties: false,
      },
    },
    confidence: { type: "string", enum: ["low", "medium", "high"] },
    notes: {
      type: "string",
      description: "One short sentence on the main assumption you made, especially about cooking fat or portion size.",
    },
  },
  required: ["meal_name", "items", "confidence", "notes"],
  additionalProperties: false,
} as const;

/**
 * The prompt does the heavy lifting on regional accuracy: it names the
 * person's cuisine, tells the model not to default to Western portions, and
 * folds in whatever correction they spoke or typed.
 */
function buildPrompt(cuisineContext: string, correction: string): string {
  const parts = [
    "Estimate the calories in this meal photo for a tracking app. Break the plate into its distinct components and give each one its own line with the portion you think you see and the calories for that portion.",
    "For every component also give protein, carbohydrate, fat, fibre and sugar in grams and sodium in milligrams for the same portion. Keep them consistent with the calories (protein and carbs 4 kcal/g, fat 9 kcal/g) and with the recipe you assumed.",
    "Be realistic about cooking fat. Photos cannot show oil, ghee, butter, cream or sugar that is already cooked into a dish, and under-counting it is the most common way these estimates go wrong. Assume normal home-cooking amounts for the cuisine unless the food looks dry or explicitly plain.",
  ];

  if (cuisineContext) {
    parts.push(
      `The person eating this describes their cooking as: "${cuisineContext}". Use the dish names, typical recipes, cooking fats and portion sizes of that cuisine rather than Western database equivalents, which routinely misjudge these dishes.`,
    );
  } else {
    parts.push(
      "Identify the cuisine from the photo and use portion sizes and recipes typical of that cuisine. Do not substitute a generic Western equivalent for a regional dish — name the actual dish where you recognise it.",
    );
  }

  if (correction) {
    parts.push(
      `The person has added this correction about the meal, which the photo may not show — treat it as authoritative and fold it into your estimate: "${correction}"`,
    );
  }

  return parts.join("\n\n");
}

export async function estimateMeal(
  client: Anthropic,
  image: { data: string; mediaType: ImageMediaType },
  cuisineContext: string,
  correction: string,
): Promise<MealEstimate> {
  const response = await client.messages.create({
    model: MODEL,
    max_tokens: 2500,
    output_config: { format: { type: "json_schema", schema: outputSchema } },
    messages: [
      {
        role: "user",
        content: [
          { type: "image", source: { type: "base64", media_type: image.mediaType, data: image.data } },
          { type: "text", text: buildPrompt(cuisineContext, correction) },
        ],
      },
    ],
  });

  if (response.stop_reason === "refusal") {
    throw new EstimateRefusedError("The model declined to analyze this image.");
  }
  if (response.stop_reason === "max_tokens") {
    throw new EstimateMalformedError("The estimate was cut off — try a photo with fewer items.");
  }

  const text = response.content.find((block) => block.type === "text");
  if (!text || text.type !== "text") {
    throw new EstimateMalformedError("No estimate in the response.");
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(text.text);
  } catch {
    throw new EstimateMalformedError("The estimate wasn't valid JSON.");
  }
  return sanitize(parsed);
}

/** Never hand the app something it can't decode, however the model replies. */
function sanitize(raw: unknown): MealEstimate {
  if (typeof raw !== "object" || raw === null) throw new EstimateMalformedError("Unexpected estimate shape.");
  const value = raw as Record<string, unknown>;
  if (!Array.isArray(value.items)) throw new EstimateMalformedError("Estimate has no items.");

  const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? Math.max(0, v) : 0);
  const str = (v: unknown, max: number) => (typeof v === "string" ? v.trim().slice(0, max) : "");

  const items: MealItem[] = value.items.slice(0, 30).flatMap((entry): MealItem[] => {
    if (typeof entry !== "object" || entry === null) return [];
    const item = entry as Record<string, unknown>;
    const name = str(item.name, 80);
    if (!name) return [];
    return [
      {
        name,
        calories: Math.round(num(item.calories)),
        portion: str(item.portion, 60) || "1 serving",
        protein_g: num(item.protein_g),
        carbs_g: num(item.carbs_g),
        fat_g: num(item.fat_g),
        fiber_g: num(item.fiber_g),
        sugar_g: num(item.sugar_g),
        sodium_mg: num(item.sodium_mg),
      },
    ];
  });
  if (items.length === 0) throw new EstimateMalformedError("Couldn't find any food in the photo.");

  const confidence = value.confidence === "low" || value.confidence === "high" ? value.confidence : "medium";
  return {
    meal_name: str(value.meal_name, 60) || "Meal",
    items,
    confidence,
    notes: str(value.notes, 300),
  };
}
