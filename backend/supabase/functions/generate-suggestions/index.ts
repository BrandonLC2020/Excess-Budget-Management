import "@supabase/functions-js/edge-runtime.d.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { excessFunds, goals, accounts, recentAllocations, defaultSavingsRatio } = await req.json()

    // Retrieve the Gemini API key from environment variables
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')
    if (!geminiApiKey) {
      throw new Error("GEMINI_API_KEY is not set")
    }

    const { totalSavings, totalPurchases } = recentAllocations || { totalSavings: 0, totalPurchases: 0 };

    const promptText = `
    You are a financial advisor. The user has an excess budget of $${excessFunds} this month.
    They want to distribute this money into their accounts and towards their savings goals.
    Prioritize short term goals and near target dates.

    The user values a balance between 'savings' goals (responsible future planning) and 'purchase' goals (immediate treats). 
    Every goal provided now includes a 'category' field indicating its type.

    Goals may now contain 'sub_goals'. The parent goal's target amount is the sum of these subgoals. 
    You may suggest allocations to the parent goal as a whole, or call out specific subgoals in your reasoning (e.g., 'Allocating $129 specifically to finish funding the Apple Pencil subgoal within your iPad fund').

    In the last 30 days, the user allocated $${totalSavings} to savings and $${totalPurchases} to purchases.
    Your suggestions must actively balance these categories. 
    - If recent history heavily favors savings, bias this $${excessFunds} allocation toward active 'purchase' goals to reward the user. 
    - If history heavily favors purchases, bias toward 'savings' goals. 
    - If recent history is $0 for both (new user), use the user's preferred default savings ratio of ${defaultSavingsRatio * 100}% savings to balance the allocation.
    - If a goal category has no active goals, allocate according to the available goals.

    Provide a brief explanation of this balance and any specific subgoals targeted in the 'reason' field.
    `
Here are their active goals:
${JSON.stringify(goals, null, 2)}

Here are their accounts:
${JSON.stringify(accounts, null, 2)}

Based on this information, provide a structured JSON suggestion on how they should allocate the $${excessFunds}. 
The JSON must have the following format exactly, without any backticks, code blocks, or unstructured text:
{
  "allocations": [
    {
      "type": "goal" | "account",
      "id": "UUID_OF_GOAL_OR_ACCOUNT",
      "name": "Name of the goal or account",
      "amount": Number (allocation amount),
      "reason": "String explaining why this allocation makes sense"
    }
  ],
  "totalAllocated": Number (must equal ${excessFunds})
}
`

    // Call Gemini API via fetch
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: promptText,
            }],
          }],
          generationConfig: {
            temperature: 0.2,
            responseMimeType: "application/json"
          }
        }),
      }
    )

    if (!response.ok) {
      const errorText = await response.text()
      console.error("Gemini API Error:", errorText)
      throw new Error("Failed to generate suggestions")
    }

    const result = await response.json()
    const generatedText = result.candidates?.[0]?.content?.parts?.[0]?.text

    if (!generatedText) {
      throw new Error("Invalid response format from Gemini")
    }

    // Attempt to parse the generated JSON
    let parsedSuggestions;
    try {
      parsedSuggestions = JSON.parse(generatedText);
    } catch (e) {
      console.error("Failed to parse Gemini output as JSON", generatedText);
      throw new Error("Gemini produced unparseable JSON");
    }

    return new Response(JSON.stringify(parsedSuggestions), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (err) {
    const error = err as Error;
    console.error(error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
