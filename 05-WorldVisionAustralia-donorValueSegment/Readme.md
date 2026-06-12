# Donor Value Segmentation for a Charity Re-engagement Program

**Industry Capstone — Deakin University × World Vision Australia**
*Dang Viet Phuong · 6-person analytics team*

> *Built on confidential World Vision Australia supporter data. Charts show segment-level proportions and average gift from the FY24 analysis; absolute donor counts and total revenue are withheld, and no individual records are shown.*

**My role:** Led the **donor value segmentation** workstream.
**Stack:** SQL · Python · Power BI. Source data spanned Oracle **Responsys** campaign activity, donation records, supporter tenure, and **Helix Persona** segments.

---

## The problem

World Vision Australia runs *Bounceback*, a program that re-engages lapsed supporters across three campaign types — Christmas, Birthday, and Education. Every supporter moved through the **same fixed communication journey**, regardless of how much they gave or how quickly they responded. It was operationally simple, but it over-communicated to some supporters while under-serving the most valuable ones. Our team's task was to find where this one-size-fits-all journey was leaving value on the table.

I owned one dimension of that question: **are some donor groups worth disproportionately more, and should the journey treat them differently?**

## Approach

I classified supporters into **High / Medium / Low value bands using percentile thresholds on donation value, calculated separately within each campaign**, then quantified how concentrated revenue actually was inside each band. In FY24 this split donors into roughly **half Low, a third Medium, and a top ~15–18% High** within each campaign.

Three deliberate choices sit behind that, each of which I can defend:

**Percentiles, not fixed dollar cut-offs.** Donation values are heavily right-skewed — a long tail of larger gifts. Percentiles handle that skew without inventing an arbitrary "$X = High" line, and they adapt automatically to each campaign's scale. The trade-off I'd flag: percentile bands shift as the population changes, so they're a less stable long-term business *rule* than a fixed threshold — a reason to revisit them periodically. (They also don't split donor counts into clean 50/30/20 buckets, because gifts cluster at round amounts — hence the ~15–18% High band rather than exactly 20%.)

**Per campaign, not pooled.** This was a decision-unit choice, not a statistical one. The per-gift economics are actually similar across campaigns — the average High-band gift is ~$190 whether Birthday, Christmas, or Education — so pooling wouldn't have badly distorted the bands. I segmented per campaign because the *Bounceback journeys are campaign-triggered*: the segmentation feeds per-campaign journey design (timing, channel sequencing), so the unit I segment on should match the unit I'm making decisions on. The trade-off is that a single supporter active in several campaigns gets a separate band in each, rather than one consolidated value — which is the right call for journey design but not for a relationship-level view (see *What I'd do next*).

**Validated, not assumed.** Rather than trust that the top 20% mattered, I measured the share of total revenue each band actually captured — turning a convention into evidence.

<img width="2350" height="985" alt="image" src="https://github.com/user-attachments/assets/9d713587-09c4-48bc-bb0b-c05956ad82e7" />


## What I found

- Donor value was **strongly concentrated in every campaign.** The High band — only ~15–18% of donors — generated roughly **60–65% of revenue** (Birthday ~64%, Christmas ~65%, Education ~59%), while the bottom half of donors contributed about **10%**.
- The gap is driven by gift size: the average **High-band gift (~$187) was about 18× a Low-band gift (~$10).** A small number of supporters were doing most of the financial work.
- This concentration was **masked by the uniform journey** — high-value supporters received the same treatment as everyone else, exposing the program to churn risk among exactly the donors it could least afford to lose.
- The pattern held across all three campaigns, which is *why* it justified a structural change rather than a one-campaign tweak.

## Recommendation

Move from a uniform journey to a **value-tiered one**: protect and prioritise the High band, design uplift paths for the Medium band, and apply cost-controlled contact for the Low band — **without cutting the total number of touches**, only re-ordering and re-weighting them. This fed the team's combined recommendation for a segmentation dashboard that overlays value band with response speed and channel.

## What I'd do next

Two extensions, both aimed at a **relationship-level** view rather than a campaign-level one:

**Aggregate to donor-level lifetime value.** The current bands are computed per campaign, so the same supporter can sit in different bands across campaigns. For a "who are our most valuable supporters, full stop?" view, I'd roll value up to one band per donor across all campaigns — the donor-level LTV cut that targeting and personalisation decisions actually need. The principle: the unit you segment on should match the decision you're driving — campaign-level for journey design, donor-level for lifetime value.

**Extend monetary-only bands to full RFM** (recency, frequency, monetary). The donation data carries dates and repeat gifts, so the inputs already exist. RFM would distinguish a lapsing high-value donor from a loyal one at the same spend level — something a value-only band cannot — and pairs naturally with the donor-level aggregation above.

---

*Note on data: charts show segment-level aggregates (proportions and average gift) from the FY24 analysis. The underlying World Vision Australia supporter data is confidential; absolute totals and individual records are not reproduced here.*
