trades: ([] time:`time$(); sym:`symbol$(); price:`float$(); size:`long$(); side:`symbol$(); exchange:`symbol$(); tradeId:`symbol$(); orderId:`symbol$(); condition:`symbol$(); broker:`symbol$())


quotes: ([] time:`time$(); sym:`symbol$(); bid:`float$(); ask:`float$(); bsize:`long$(); asize:`long$(); exchange:`symbol$(); condition:`symbol$())


/ Used sym for tradeId and orderId even though they are not repeating, which can even bloat sym file in hdb, but it is done here because of the query convience, but this is not followed in prod.