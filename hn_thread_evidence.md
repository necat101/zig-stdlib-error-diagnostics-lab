# HN Thread Evidence – Zig Error Patterns

Source: https://news.ycombinator.com/item?id=44812985
Title: "Zig Error Patterns"
URL (article): https://glfmn.io/posts/zig-error-patterns/
Retrieved: 2026-07-06 via Hacker News Firebase API (`hackernews get-item --id 44812985`)

Score: 157, Comments: 53

## Key discussion themes (summarized)

The linked article is about using `errdefer`, `std.debug.print`, `@breakpoint`, and Zig build options to improve debugging for tests.

The HN discussion broadens significantly beyond that:

1. **Error payloads missing in Zig** – Top comment (davidkunz) asks: "how do people deal with the abstinence of payloads in zig errors? For example, when parsing a JSON string, the error `UnexpectedToken` is not very helpful. Are libraries typically designed to accept an optional input to store potential errors?"

2. **Optional diagnostic/out-parameter structs** – quantummagic: "The idiomatic way in Zig is to return the simple unadorned error, but return detailed error data through a pointer argument passed into the function". Caller arranges memory usage, no hidden allocation. Optional parameter so caller may omit it.

3. **No hidden allocation** – quantummagic: "The advantage of this is that everything is explicit, and it is up to the caller to arrange memory usage for error data; ie. the compiler does not trigger any implicit memory allocation to accommodate error returns. This is a fundamental element of Zig's design"

4. **Caller must allocate anyway** – nextaccountic counterpoint: "this has the disadvantage that the caller must allocate space for the error payload, even if the error is very unlikely"

5. **std.json diagnostics** – maleldil: "Stdlib's JSON module has a separate diagnostics object". Links https://ziglang.org/documentation/master/std/#std.json.Scanner.Diagnostics. Calls this "the weakest part of Zig's error handling story".

6. **std.json is NOT good error handling** – AndyKelley (Zig BDFL): "I'd like to note that std.json, as it currently stands, is not a good example of proper error handling. Unless you use that awkward lower level Scanner API, if you get a schema mismatch it reports some failure code and does not populate a diagnostics struct, which is painful and useless."

7. **std.zon did it right** – AndyKelley: "On the other hand the std.zon author did not make this mistake, i.e. `std.zon.parse.fromSlice` takes an optional Diagnostics struct which gives you all the information you need (including a handy format method for printing human readable messages)."

8. **Errors are for control flow** – jmull: "I think the idea is errors are for control flow. If you have other information to return from a function, you can just return it — whether directly as the return value or through an 'out' parameter or setting it in some context."

9. **Rust Result / anyhow comparison** – hansvm: contrasting with Rust, "suppose you want Zig's 'try' functionality with arbitrary payloads. Both functions need a compatible error type … or else you can accept a little more boilerplate and box everything with a library like `anyhow`." "does it help you solve real problems? Opinions vary, but I think it mostly makes your life harder." "since the whole point of `try` is to bubble things up to callers who don't have the appropriate context to handle them, they likely don't really care about the metadata"

10. **Union return when callers care** – hansvm: "Suppose you want Zig's 'catch' functionality with arbitrary payloads. That's just a `union` type. If you actually expect callers to inspect and care about the details of each possible return branch, you should provide a return type allowing them to do stuff with that information."

11. **errdefer praised** – Multiple commenters. skrebbel: "Wow, errdefer sounds like the kind of thing every language ought to have." etyp: "`errdefer` patterns in tests are super nice!"

12. **errdefer vs try-catch** – jayd16: "Is it significantly different than a try-catch block?" skrebbel: "Yeah it lets you put code that goes in 'catch' all over your function body, right next to where it's most relevant."

13. **C-style out parameters** – metaltyphoon: "So… pretty much how C does it." quantummagic replies: "The main difference is that C doesn't have error (result types) baked into the language."

14. **Culture and coding standards** – dwattttt: "Culture and coding standards count for a lot. C _can_ do this, but it's not normal to. If Zig can foster a culture of handling errors this way, it'll be the way the community writ large handle errors."

15. **Odin comparison** – mark38848: "It's still complete dogshit not to be able to have data there. Odin is much better here, iirc"

16. **Error payloads issue** – delifue: "In my opinion Zig is elegant except for one thing: cannot attach data to error." Links https://github.com/ziglang/zig/issues/2647. nektro replies: "this is because attaching a payload requires asking the question of who and how the memory of such a payload is managed, and Zig the language never prescribes you into a particular answer to that question."

17. **Debugger / build options** – ww520: "These are excellent tips. I especially like the debugger integration in build.zig. I used to grep the cache directory to find the exe."

18. **Caller-specified return type** – hansvm: "Something I also do in a fair amount of my code is let the caller specify my return type, and I'll avoid work if they don't request a certain payload (e.g., not adding parse failure line numbers if not requested)."

The HN thread was accessed via the Hacker News API CLI before writing the README sentiment summary. Direct quotes above are short excerpts for evidence purposes. The README sentiment section summarizes these themes in the lab author's own words.

Full comment tree saved as hn_comments_sanitized.json (53 comments).
