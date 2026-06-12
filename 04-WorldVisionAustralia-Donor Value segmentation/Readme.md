# Donor Value Segmentation for a Charity Re-engagement Program

**Industry Capstone — Deakin University × World Vision Australia**
*Dang Viet Phuong · 6-person analytics team*

> *Built on confidential World Vision Australia supporter data. All figures shown are illustrative of the analytical approach, not actual values.*

**My role:** Led the **donor value segmentation** workstream.
**Stack:** SQL · Python · Power BI. Source data spanned Oracle **Responsys** campaign activity, donation records, supporter tenure, and **Helix Persona** segments.

---

## The problem

World Vision Australia runs *Bounceback*, a program that re-engages lapsed supporters across three campaign types — Christmas, Birthday, and Education. Every supporter moved through the **same fixed communication journey**, regardless of how much they gave or how quickly they responded. It was operationally simple, but it over-communicated to some supporters while under-serving the most valuable ones. Our team's task was to find where this one-size-fits-all journey was leaving value on the table.

I owned one dimension of that question: **are some donor groups worth disproportionately more, and should the journey treat them differently?**

## Approach

I classified supporters into **High / Medium / Low value bands using percentile thresholds, calculated separately within each campaign**, then quantified how concentrated revenue actually was inside each band.

- **Low** — bottom 50% of donors by total value
- **Medium** — 50th–80th percentile
- **High** — top 20%

Three deliberate choices sit behind that, each of which I can defend:

**Percentiles, not fixed dollar cut-offs.** Donation values are heavily right-skewed — a long tail of larger gifts (left panel below). Percentiles handle that skew without inventing an arbitrary "$X = High" line, and they adapt automatically to each campaign's scale. The trade-off I'd flag: percentile bands shift as the population changes, so they're a less stable long-term business *rule* than a fixed threshold — a reason to revisit them periodically.

**Per campaign, not pooled.** Christmas gifts run larger on average than Education gifts. Pooling everyone would flood the High band with Christmas donors and make Education look like it has almost no high-value supporters — an artefact of campaign type, not of donor worth. Banding *within* each campaign keeps the comparison fair.

**Validated, not assumed.** Rather than trust that the top 20% mattered, I measured the share of total revenue each band actually captured — turning a convention into evidence.

![Illustrative value-segmentation figure](wva_value_segmentation_illustrative.png)

## What I found

- Within every campaign, donor value was **strongly concentrated**: a small high-value minority accounted for a disproportionate share of revenue, while the bottom half of donors contributed a thin slice.
- That concentration was **masked by the uniform journey** — high-value supporters received the same treatment as low-value ones, exposing the program to churn risk among exactly the donors it could least afford to lose.
- The pattern held across all three campaigns but at **different scales**, reinforcing the case for treating campaigns (and donor tiers within them) distinctly rather than identically.

## Recommendation

Move from a uniform journey to a **value-tiered one**: protect and prioritise the High band, design uplift paths for the Medium band, and apply cost-controlled contact for the Low band — **without cutting the total number of touches**, only re-ordering and re-weighting them. This fed the team's combined recommendation for a segmentation dashboard that overlays value band with response speed and channel.

## What I'd do next

The value bands segment on **monetary value alone**. The natural production upgrade is full **RFM** (recency, frequency, monetary) — the donation data carries dates and repeat gifts, so the inputs already exist. RFM would distinguish a lapsing high-value donor from a loyal one at the same spend level, which a value-only band cannot. That's the first extension I'd build with more time.

---

*Note on data: figures and proportions in this case study are illustrative of the method. The underlying World Vision Australia supporter data is confidential and is not reproduced here.*
