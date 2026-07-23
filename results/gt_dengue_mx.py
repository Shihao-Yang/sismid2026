#!/usr/bin/env python3
"""Pull Google Trends for dengue-related terms in Mexico, past 5 years."""
import os
import time

import matplotlib.pyplot as plt
import pandas as pd
from pytrends.request import TrendReq

HERE = os.path.dirname(os.path.abspath(__file__))
GEO = "MX"
TERMS = ["dengue", "sintomas de dengue", "mosquito"]
TIMEFRAME = "today 5-y"


def norm(c):
    return c.strip().replace(" ", "_")


def fetch(pt, kw_list, timeframe, geo):
    pt.build_payload(kw_list, timeframe=timeframe, geo=geo)
    df = pt.interest_over_time()
    if df.empty:
        return None
    df = df.drop(columns=[c for c in ["isPartial"] if c in df.columns]).reset_index()
    return df.rename(columns={c: norm(c) for c in df.columns})


def main():
    df = None
    for attempt in range(6):
        pt = TrendReq(hl="en-US", tz=360)
        try:
            df = fetch(pt, TERMS, TIMEFRAME, GEO)
        except Exception as e:  # pytrends raises on 429 rather than returning empty
            print(f"request error ({e}), attempt {attempt + 1}/6")
            df = None
        if df is not None:
            break
        wait = 30 * (attempt + 1)
        print(f"empty/rate-limited response, retrying in {wait}s...")
        time.sleep(wait)

    if df is None:
        raise SystemExit("Google Trends pull failed after retries (likely rate-limited).")

    df.to_csv(os.path.join(HERE, "gt_dengue_mx.csv"), index=False)

    cols = [norm(t) for t in TERMS]
    ax = df.plot(x="date", y=cols, figsize=(10, 5))
    ax.set_title("Google Trends: dengue-related search interest in Mexico (past 5 years)")
    ax.set_xlabel("Date")
    ax.set_ylabel("Relative search interest (0-100)")
    plt.tight_layout()
    plt.savefig(os.path.join(HERE, "gt_dengue_mx.png"), dpi=150)

    print(df.tail())
    print("\nLast point date:", df["date"].max().date())


if __name__ == "__main__":
    main()
