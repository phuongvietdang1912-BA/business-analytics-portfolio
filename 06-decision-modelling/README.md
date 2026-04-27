# Donor Journey Optimisation for World Vision Australia

## Business Analytics Case Study | Power BI | Donor Segmentation | Channel Strategy

This project analyses World Vision Australia’s supporter re-engagement journeys to understand how different donor groups respond to fundraising messages across campaign types, communication channels, and timing windows.

The goal was to identify whether a one-size-fits-all donor journey was causing delayed donations, unnecessary follow-up messages, and lower engagement after repeated contact.

> Note: This project was completed as part of a university-industry analytics project using World Vision Australia case data. It should not be interpreted as employment experience with World Vision Australia.

---

## 1. Business Problem

World Vision Australia uses supporter re-engagement campaigns to encourage inactive or lapsed donors to give again.

The issue is that different donor groups do not behave the same way. Some donors respond quickly, some require longer nurturing, and others stop responding after repeated messages.

A fixed communication journey creates several business risks:

- Fast-response donors may receive unnecessary follow-up messages.
- Slower but valuable donors may need a different nurturing approach.
- Low-response segments may receive repeated messages with limited return.
- Campaign teams may not know which channel should be used at each stage.
- High-value donors may not be prioritised appropriately.

The key business question was:

**How can World Vision Australia improve donor re-engagement by matching communication timing, channel choice, and donor value to actual supporter behaviour?**

---

## 2. Project Objectives

This project aimed to:

- Identify whether donors behave differently across Birthday, Christmas, and Education campaigns.
- Measure how quickly donors give after the first campaign message.
- Understand which communication channels work best at different journey stages.
- Segment donors by contribution value and response behaviour.
- Identify where repeated messages become less effective.
- Recommend a more targeted donor journey strategy.

---

## 3. Data and Scope

The analysis focused on three fundraising campaign types:

- Birthday
- Christmas
- Education

The project analysed donor behaviour across four main dimensions:

| Area | Purpose |
|---|---|
| Donation speed | Measure how long it takes supporters to donate after first contact |
| Campaign type | Compare behaviour across Birthday, Christmas, and Education campaigns |
| Communication channel | Understand how Direct Mail, SMS, and Email perform across journey stages |
| Donor value | Identify high, medium, and low-value supporter groups |
| Engagement decay | Analyse whether supporter response declines after repeated messages |

The analysis used behavioural variables only. Demographic and motivational data were not available.

---

## 4. Analytical Approach

The project followed a diagnostic analytics approach.

Instead of only reporting campaign performance, the analysis investigated why some supporter journeys performed better than others.

The analysis was structured around four questions:

1. Do donors respond at different speeds across campaign types?
2. Which channels are most effective at different stages of the journey?
3. Which donor groups contribute the most value?
4. Does supporter response decline after repeated messages?

Key metrics included:

- Donation speed
- Days from first contact to first donation
- Donation value
- Engagement rate
- Conversion rate by touchpoint
- Channel response pattern
- Donor value segment
- Campaign-level performance

---

## 5. Key Findings

### Finding 1: Donor behaviour differs by campaign type

The analysis showed that donors do not respond in the same way across campaigns.

- **Birthday donors** converted quickly, with donations concentrated early in the journey.
- **Christmas donors** required a longer nurturing period and generated stronger overall value.
- **Education donors** showed an “early-or-never” pattern, where donors who converted tended to do so early, while later-stage conversion was weaker.

This means a single fixed journey does not match the behaviour of all donor groups.

---

### Finding 2: Different channels work best at different journey stages

The analysis found clear differences in channel behaviour:

- **Direct Mail** was strongest at the first contact.
- **SMS** worked well as a reminder after the first message.
- **Email** was more useful for longer-term nurturing.

This suggests that channels should not be treated equally. Each channel plays a different role in the donor journey.

---

### Finding 3: Donor value is uneven across campaigns

Donation value differed significantly across campaign types.

- Christmas generated the highest total donation value and strongest average gift.
- Birthday showed stable donation value.
- Education generated lower total value and lower average gift.

The value segmentation also showed that a small group of high-value donors contributed disproportionately to overall donation value.

This means donor journeys should protect high-value supporters, uplift medium-value supporters, and use more cost-conscious communication for lower-value segments.

---

### Finding 4: Engagement declines after repeated messages

Supporter engagement was strongest at early journey stages and declined after repeated contact.

This suggests that later messages should not be sent automatically to every supporter. Instead, later-stage communication should be based on response signals, campaign type, and donor value.

---

## 6. Business Recommendations

### Recommendation 1: Replace the fixed journey with campaign-specific messaging strategies

World Vision Australia should avoid applying the same communication sequence to all donor groups.

Instead, each campaign should use a journey design that reflects donor behaviour.

| Campaign | Behaviour Pattern | Recommended Strategy |
|---|---|---|
| Birthday | Fast response | Use a short, front-loaded journey with early Direct Mail or SMS |
| Christmas | Slower but higher value | Use a longer nurture journey with strong value messaging |
| Education | Early-or-never response | Place the strongest message in the first two contacts and gate later follow-ups |

The goal is not simply to reduce messages. The goal is to send the right message, through the right channel, at the right stage.

---

### Recommendation 2: Use channel sequencing based on response behaviour

The analysis suggests a more structured channel strategy:

- Use **Direct Mail** for early conversion opportunities.
- Use **SMS** as a timely reminder.
- Use **Email** for longer nurturing and lower-cost follow-up.

Once a supporter’s preferred response channel is identified, future communication should prioritise that channel.

---

### Recommendation 3: Build a Donor Value Segmentation Dashboard

A dashboard should help campaign teams classify supporters by:

- Campaign type
- Donation speed
- Donor value
- First response channel
- Engagement stage

The dashboard should help answer questions such as:

- Which donor groups should receive Direct Mail first?
- Which donors should receive SMS reminders?
- Which donors should be nurtured by Email?
- Which high-value donors need stronger protection?
- Which late-stage follow-ups should be reduced or targeted?

---

## 7. Dashboard Concept

The proposed dashboard would include the following views:

### Campaign Overview

Shows total donation value, average donation value, donor count, and conversion behaviour across Birthday, Christmas, and Education campaigns.

### Donation Speed Analysis

Compares how quickly donors give after the first campaign message.

### Channel Performance Analysis

Shows which channels perform best at each journey stage.

### Donor Value Segmentation

Classifies supporters into low, medium, and high-value groups.

### Engagement Decay Analysis

Identifies where supporter response declines after repeated messages.

### Recommendation View

Provides suggested journey strategies based on campaign type, donor value, response speed, and channel behaviour.

---

## 8. Tools and Skills Used

### Tools

- Power BI
- DAX
- Data modelling
- Excel
- Data visualisation

### Business Analytics Skills

- Diagnostic analysis
- Donor segmentation
- Campaign performance analysis
- Journey optimisation
- Channel performance analysis
- KPI design
- Insight generation
- Business recommendation development

### Business Analysis Skills

- Problem framing
- Stakeholder-focused reporting
- Requirement thinking
- Decision-support dashboard design
- Translating data insights into business actions

---

## 9. Project Deliverables

This project includes:

- Business case study write-up
- Power BI dashboard screenshots
- Donor journey analysis
- Campaign performance analysis
- Channel response analysis
- Donor value segmentation
- Business recommendations

Suggested repository structure:

```text
WVA_Donor_Journey_Optimisation/
│
├── README.md
├── reports/
│   └── WVA_Donor_Journey_Report.pdf
│
├── dashboard/
│   ├── dashboard_screenshot_1.png
│   ├── dashboard_screenshot_2.png
│   └── dashboard_screenshot_3.png
│
├── powerbi/
│   └── WVA_Donor_Journey_Dashboard.pbix
│
├── data_dictionary/
│   └── data_dictionary.md
│
└── notes/
    └── methodology_notes.md
