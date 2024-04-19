with tab1 as (
    select
        visitor_id,
        visit_date,
        source as utm_source,
        medium as utm_medium,
        campaign as utm_campaign,
        row_number()
        over (partition by visitor_id order by visit_date desc)
        as rn
    from sessions
    where medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),


tab as (
    select
        visitor_id,
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign
    from tab1
    where rn = 1
),

tab2 as (
    select
        tab.visitor_id,
        tab.utm_source,
        tab.utm_medium,
        tab.utm_campaign,
        date(tab.visit_date) as visit_date,
        case
            when tab.visit_date <= l.created_at then l.lead_id
        end as lead_id,
        case
            when tab.visit_date <= l.created_at then l.created_at
        end as created_at,
        case
            when tab.visit_date <= l.created_at then l.amount
        end as amount,
        case
            when tab.visit_date <= l.created_at then l.closing_reason
        end as closing_reason,
        case
            when tab.visit_date <= l.created_at then l.status_id
        end as status_id
    from tab
    left join leads as l
        on tab.visitor_id = l.visitor_id
    order by
        amount desc nulls last,
        date(visit_date),
        tab.utm_source asc,
        tab.utm_medium asc,
        tab.utm_campaign asc
),

tab3 as (
    (
        select
            ad_id,
            campaign_id,
            campaign_name,
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            daily_spent,
            date(campaign_date) as date1
        from ya_ads
    )
    union all
    (
        select
            ad_id,
            campaign_id,
            campaign_name,
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            daily_spent,
            date(campaign_date) as date1
        from vk_ads
    )
),

tab4 as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date1,
        sum(daily_spent) as daily_spent
    from tab3
    group by utm_source, utm_medium, utm_campaign, date1
),

tab5 as (
    select
        tab2.visitor_id,
        tab2.visit_date,
        tab2.utm_source,
        tab2.utm_medium,
        tab2.utm_campaign,
        tab2.lead_id,
        tab2.created_at,
        tab2.amount,
        tab2.closing_reason,
        tab2.status_id,
        tab4.daily_spent
    from tab2
    left join tab4
        on
            tab2.utm_source = tab4.utm_source
            and tab2.utm_medium = tab4.utm_medium
            and tab2.utm_campaign = tab4.utm_campaign
            and tab2.visit_date = tab4.date1
)

select
    visit_date,
    utm_source,
    utm_medium,
    utm_campaign,
    daily_spent as total_cost,
    count(visitor_id) as visitors_count,
    count(lead_id) as leads_count,
    count(lead_id) filter (where status_id = 142) as purchases_count,
    sum(amount) filter (where status_id = 142) as revenue
from tab5
group by
    visit_date,
    utm_source,
    utm_medium,
    utm_campaign,
    daily_spent
order by
    revenue desc nulls last,
    visit_date asc,
    visitors_count desc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc;
