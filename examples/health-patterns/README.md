# Health patterns, end to end (sandbox)

A synthetic sandbox patient with a planted pattern, read the way an app or agent would:

1. find the persona (`p01`: home blood pressure falling over six months);
2. run the pattern engine on the last 180 days and print the supported findings with their period, method maturity and limitations;
3. list the resources behind the first one;
4. read the method registry (which methods may reach a person);
5. write a synthetic PHQ-9 answer that triggers the `X-Anpheros-Safety` header, and fetch the crisis lines.

```bash
npm install
ANPHEROS_KEY=sk_test_… node patterns.mjs        # or: node patterns.mjs p06  (a headache every 7 days)
```

Findings describe what the record shows: not a diagnosis, not a cause, never a reason to change a medicine. In the
sandbox `shown` stays false: stored findings and the display rule exist only for the trusted first-party project under
a person's own consent. Every value here is synthetic.

Guide: https://developers.anpheros.com/guides/health-patterns-api
