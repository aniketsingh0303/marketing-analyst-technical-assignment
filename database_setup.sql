-- Senior Marketing Analyst Technical Assignment
-- Database Setup and Data Unification Script
-- PostgreSQL Cloud Database Solution

-- Create separate tables for each platform's data
CREATE TABLE facebook_ads (
    date DATE,
    campaign_id VARCHAR(50),
    campaign_name VARCHAR(255),
    ad_set_id VARCHAR(50),
    ad_set_name VARCHAR(255),
    impressions INTEGER,
    clicks INTEGER,
    spend DECIMAL(10,2),
    conversions INTEGER,
    video_views INTEGER,
    engagement_rate DECIMAL(5,4),
    reach INTEGER,
    frequency DECIMAL(4,2),
    platform VARCHAR(20) DEFAULT 'Facebook'
);

CREATE TABLE google_ads (
    date DATE,
    campaign_id VARCHAR(50),
    campaign_name VARCHAR(255),
    ad_group_id VARCHAR(50),
    ad_group_name VARCHAR(255),
    impressions INTEGER,
    clicks INTEGER,
    cost DECIMAL(10,2),
    conversions INTEGER,
    conversion_value DECIMAL(10,2),
    ctr DECIMAL(5,4),
    avg_cpc DECIMAL(6,2),
    quality_score INTEGER,
    search_impression_share DECIMAL(4,2),
    platform VARCHAR(20) DEFAULT 'Google'
);

CREATE TABLE tiktok_ads (
    date DATE,
    campaign_id VARCHAR(50),
    campaign_name VARCHAR(255),
    adgroup_id VARCHAR(50),
    adgroup_name VARCHAR(255),
    impressions INTEGER,
    clicks INTEGER,
    cost DECIMAL(10,2),
    conversions INTEGER,
    video_views INTEGER,
    video_watch_25 INTEGER,
    video_watch_50 INTEGER,
    video_watch_75 INTEGER,
    video_watch_100 INTEGER,
    likes INTEGER,
    shares INTEGER,
    comments INTEGER,
    platform VARCHAR(20) DEFAULT 'TikTok'
);

-- Copy data from CSV files (this would be done via database import tools)
-- COPY facebook_ads FROM '01_facebook_ads.csv' CSV HEADER;
-- COPY google_ads FROM '02_google_ads.csv' CSV HEADER;
-- COPY tiktok_ads FROM '03_tiktok_ads.csv' CSV HEADER;

-- Create unified advertising data model
CREATE TABLE unified_ads AS
SELECT 
    date,
    campaign_id,
    campaign_name,
    COALESCE(ad_set_name, ad_group_name, adgroup_name) as ad_group_name,
    impressions,
    clicks,
    COALESCE(spend, cost) as spend,
    conversions,
    CASE 
        WHEN platform = 'Facebook' THEN video_views
        WHEN platform = 'TikTok' THEN video_views
        ELSE 0
    END as video_views,
    CASE 
        WHEN platform = 'Facebook' THEN engagement_rate
        WHEN platform = 'Google' THEN ctr
        ELSE 0
    END as engagement_rate,
    platform,
    CASE 
        WHEN platform = 'Google' THEN conversion_value
        ELSE spend * 2.5  -- Estimated conversion value for other platforms
    END as conversion_value,
    CASE 
        WHEN clicks > 0 THEN spend / clicks
        ELSE 0
    END as avg_cpc,
    CASE 
        WHEN impressions > 0 THEN (clicks::DECIMAL / impressions) * 100
        ELSE 0
    END as ctr_percent
FROM (
    SELECT *, 'Facebook' as platform FROM facebook_ads
    UNION ALL
    SELECT *, 'Google' as platform FROM google_ads  
    UNION ALL
    SELECT *, 'TikTok' as platform FROM tiktok_ads
) combined_data;

-- Create indexes for better performance
CREATE INDEX idx_unified_date ON unified_ads(date);
CREATE INDEX idx_unified_platform ON unified_ads(platform);
CREATE INDEX idx_unified_campaign ON unified_ads(campaign_id);

-- Create summary views for dashboard
CREATE VIEW daily_performance AS
SELECT 
    date,
    platform,
    SUM(impressions) as total_impressions,
    SUM(clicks) as total_clicks,
    SUM(spend) as total_spend,
    SUM(conversions) as total_conversions,
    SUM(conversion_value) as total_conversion_value,
    AVG(ctr_percent) as avg_ctr,
    AVG(avg_cpc) as avg_cpc,
    CASE 
        WHEN SUM(spend) > 0 THEN (SUM(conversion_value) - SUM(spend)) / SUM(spend) * 100
        ELSE 0
    END as roi_percent
FROM unified_ads
GROUP BY date, platform
ORDER BY date, platform;

CREATE VIEW campaign_performance AS
SELECT 
    campaign_name,
    platform,
    SUM(impressions) as total_impressions,
    SUM(clicks) as total_clicks,
    SUM(spend) as total_spend,
    SUM(conversions) as total_conversions,
    SUM(conversion_value) as total_conversion_value,
    AVG(ctr_percent) as avg_ctr,
    AVG(avg_cpc) as avg_cpc,
    CASE 
        WHEN SUM(spend) > 0 THEN SUM(conversions)::DECIMAL / SUM(spend) * 100
        ELSE 0
    END as conversion_rate,
    CASE 
        WHEN SUM(spend) > 0 THEN (SUM(conversion_value) - SUM(spend)) / SUM(spend) * 100
        ELSE 0
    END as roi_percent
FROM unified_ads
GROUP BY campaign_name, platform
ORDER BY total_spend DESC;

CREATE VIEW cross_channel_summary AS
SELECT 
    platform,
    COUNT(DISTINCT campaign_id) as total_campaigns,
    SUM(impressions) as total_impressions,
    SUM(clicks) as total_clicks,
    SUM(spend) as total_spend,
    SUM(conversions) as total_conversions,
    SUM(conversion_value) as total_conversion_value,
    AVG(ctr_percent) as avg_ctr,
    AVG(avg_cpc) as avg_cpc,
    CASE 
        WHEN SUM(spend) > 0 THEN SUM(conversions)::DECIMAL / SUM(spend) * 100
        ELSE 0
    END as conversion_rate,
    CASE 
        WHEN SUM(spend) > 0 THEN (SUM(conversion_value) - SUM(spend)) / SUM(spend) * 100
        ELSE 0
    END as roi_percent
FROM unified_ads
GROUP BY platform
ORDER BY total_spend DESC;