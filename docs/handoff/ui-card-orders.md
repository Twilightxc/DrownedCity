# ui/card-orders

- **PR:** opening (pushed? yes)
- **Machine:** laptop (ASUS, Arc 140V)
- **Base:** main @ 924dab5
- **Updated:** 2026-11-06

## J asked
"ทำงานโค้ดทั้งหมดก่อนส่งต่อเครื่องdesktop". This is left over from the orders wheel (PR #57): until now, only the
wheel showed the orders in force.

## Done
- Each teammate card shows its orders on the right of the name line, in green: "Follow · At will", "Sneak · Quiet".
  The text comes from `FighterHud.orders_text`.
- Cards are 230 px wide (was 170) so the name, a downed timer and the orders fit.
- 1 new test, 239 total, all passing (this branch is from main, without PR #62's tests).

## J must test
- Change orders with Tab: do the cards follow? Is the text readable over the water?
