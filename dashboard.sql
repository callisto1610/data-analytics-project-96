/* Сколько у нас пользователей заходят на сайт с разбивкой по дням? */

select distinct
    COUNT(visitor_id) as visitor_number,
    TO_CHAR(visit_date, 'YYYY-MM-DD') as day_number
from sessions
group by day_number
order by day_number;

/* Какие каналы их приводят на сайт? Хочется видеть по дням/неделям/месяцам */

with tab as (
    select
        source,
        count(visitor_id) as visitors_number,
        extract(month from min(visit_date)) as month,
        extract(week from min(visit_date)) as week,
        extract(day from min(visit_date)) as day
    from sessions
    group by source
)

select
    source,
    month,
    week,
    day,
    sum(visitors_number) as visitor_number
from tab
group by source, month, week, day
order by visitor_number desc;


/* Сколько лидов к нам приходят? */

select
    count(lead_id) as number_of_leads,
    date(created_at) as day
from leads
group by day
order by day

/* Какая конверсия из клика в лид? */

with tab1 as
(select count(lead_id) as leads_count,
       date(created_at) as day
from leads l
group by day),


tab2 as 
(select count(visitor_id) as clicks,
       date(visit_date) as day
from sessions s
group by day)

select round(tab1.leads_count * 100.00 / tab2.clicks, 1) as clicks_to_lead_conversion,
       tab1.day
from tab1
inner join tab2
on tab1.day = tab2.day
order by tab1.day

/* Какая конверсия из лида в оплату? */

with tab as
(select count(lead_id) as leads_count,
        count(lead_id) filter (where amount <> 0) as payment_count,
       date(created_at) as day
from leads l
group by day)

select round(payment_count * 100.00 / leads_count, 1) as lead_to_payment_conversion,
       day
from tab
order by day



/* Сколько мы тратим по разным каналам в динамике? */

with tab as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date(campaign_date) as campaign_date,
        sum(daily_spent) as total_cost
    from vk_ads
    group by utm_source, utm_medium, utm_campaign, campaign_date
    union
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date(campaign_date) as campaign_date,
        sum(daily_spent) as total_cost
    from ya_ads
    group by utm_source, utm_medium, utm_campaign, campaign_date
    order by utm_source, utm_medium, utm_campaign, campaign_date
),

tab1 as (
    select
        s.visitor_id,
        s.source,
        s.medium,
        s.campaign,
        tab.total_cost,
        date(s.visit_date) as visit_date
    from sessions as s
    left join tab
        on
            s.source = tab.utm_source
            and s.medium = tab.utm_medium
            and s.campaign = tab.utm_campaign
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
)

select
    visit_date,
    source,
    medium,
    campaign,
    sum(total_cost) as total_cost
from tab1
group by visit_date, source, medium, campaign
having sum(total_cost) > 0
order by visit_date


/* Есть ли окупаемые каналы? Если да, то какие? */

with tab as (
    select distinct on (visitor_id)
        visitor_id,
        source as utm_source,
        medium as utm_medium,
        campaign as utm_campaign,
        max(visit_date) as visit_date
    from sessions
    where medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    group by visitor_id, utm_source, utm_medium, utm_campaign
),

tab1 as (
    select
        tab.visitor_id,
        tab.visit_date,
        tab.utm_source,
        tab.utm_medium,
        tab.utm_campaign,
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
        visit_date asc,
        utm_source asc,
        utm_medium asc,
        utm_campaign asc
),

tab2 as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date(visit_date) as last_date,
        coalesce(sum(amount), 0) as revenue
    from tab1
    group by last_date, utm_source, utm_medium, utm_campaign
),

tab3 as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date(campaign_date) as campaign_date,
        sum(daily_spent) as total_cost
    from vk_ads
    group by utm_source, utm_medium, utm_campaign, campaign_date
    union
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date(campaign_date) as campaign_date,
        sum(daily_spent) as total_cost
    from ya_ads
    group by utm_source, utm_medium, utm_campaign, campaign_date
    order by utm_source, utm_medium, utm_campaign, campaign_date
),

tab4 as (
    select
        tab2.last_date as date,
        tab2.utm_source,
        tab2.utm_medium,
        tab2.utm_campaign,
        tab2.revenue,
        tab3.total_cost
    from tab2
    inner join tab3
        on
            tab2.utm_source = tab3.utm_source
            and tab2.utm_medium = tab3.utm_medium
            and tab2.utm_campaign = tab3.utm_campaign
            and tab2.last_date = tab3.campaign_date
)

select
    utm_source,
    utm_medium,
    utm_campaign,
    sum(revenue) as revenue,
    sum(total_cost) as ad_cost,
    (sum(revenue) - sum(total_cost)) as profit
from tab4
group by utm_source, utm_medium, utm_campaign
order by profit asc


/* cpu = total_cost / visitors_count
cpl = total_cost / leads_count
cppu = total_cost / purchases_count
roi = (revenue - total_cost) / total_cost * 100% */


with tab1 as (
    select
        source,
        medium,
        campaign,
        COUNT(visitor_id) as visitor_number,
        DATE(visit_date) as day_number
    from sessions
    group by day_number, source, medium, campaign
    order by day_number
),

tab2 as (
    select
        utm_source as source,
        utm_medium as medium,
        utm_campaign as campaign,
        DATE(campaign_date) as campaign_date,
        SUM(daily_spent) as total_cost
    from vk_ads
    group by source, medium, campaign, campaign_date
    union all
    select
        utm_source as source,
        utm_medium as medium,
        utm_campaign as campaign,
        DATE(campaign_date) as campaign_date,
        SUM(daily_spent) as total_cost
    from ya_ads
    group by source, medium, campaign, campaign_date
),

tab3 as (
    select
        COUNT(lead_id) as leads_count,
        COUNT(lead_id) filter (where status_id = 142) as purchase_count,
        DATE(created_at) as date,
        SUM(amount) as revenue
    from leads
    group by date
),


tab4 as (
    select
        tab1.source,
        tab1.medium,
        tab1.campaign,
        tab1.day_number as date,
        tab2.total_cost / tab1.visitor_number as cpu,
        tab2.total_cost / tab3.leads_count as cpl,
        case
            when tab3.purchase_count = 0 then 0 else
                tab2.total_cost / tab3.purchase_count
        end as cppu,
        (tab2.total_cost - tab3.revenue) * 100 / tab2.total_cost as roi
    from tab1
    left join tab2
        on
            tab1.source = tab2.source
            and tab1.medium = tab2.medium
            and tab1.campaign = tab2.campaign
            and tab1.day_number = tab2.campaign_date
    left join tab3
        on tab1.day_number = tab3.date
    order by date
)

select
    date,
    source,
    medium,
    campaign,
    COALESCE(cpu, 0) as cpu,
    COALESCE(cpl, 0) as cpl,
    COALESCE(cppu, 0) as cppu,
    COALESCE(roi, 0) as roi
from tab4
where cpu != 0 and cpl != 0 and cppu != 0 and roi != 0
order by source, date;


/* Можно посчитать за сколько дней с момента перехода по рекламе закрывается 90% лидов. */

with tab as (
    select distinct on (visitor_id)
        visitor_id,
        source as utm_source,
        medium as utm_medium,
        campaign as utm_campaign,
        min(visit_date) as visit_date
    from sessions
    group by visitor_id, utm_source, utm_medium, utm_campaign
),

tab1 as (
    select
        tab.visitor_id,
        tab.visit_date,
        tab.utm_source,
        tab.utm_medium,
        tab.utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    from tab
    left join leads as l
        on tab.visitor_id = l.visitor_id
    where
        l.status_id = 142
        and l.lead_id is not null
        and tab.visit_date < l.created_at
    order by
        amount desc nulls first,
        visit_date asc,
        utm_source asc,
        utm_medium asc,
        utm_campaign asc
),

tab2 as (
    select
        visitor_id,
        utm_source,
        utm_medium,
        utm_campaign,
        lead_id,
        (date(created_at) - date(visit_date)) as datediff
    from tab1
    where lead_id is not null
),

tab3 as (
    select
        datediff,
        count(lead_id) as lead_count
    from tab2
    group by datediff
    order by datediff
),

tab4 as (
    select
        datediff,
        sum(lead_count) over (order by datediff) as closed_leads
    from tab3
)

select
    datediff,
    round(
        closed_leads * 100 / (select sum(lead_count) from tab3), 0
    ) as closed_leads_percent
from tab4
