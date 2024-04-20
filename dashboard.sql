/* Сколько у нас пользователей заходят на сайт с разбивкой по дням? */


select
    COUNT(visitor_id) as visitor_number,
    TO_CHAR(visit_date, 'YYYY-MM-DD') as day_number
from sessions
group by day_number
order by day_number;


/* Какие каналы их приводят на сайт? Хочется видеть по дням/неделям/месяцам */


with tab as (
    select
        source,
        COUNT(visitor_id) as visitors_number,
        EXTRACT(month from MIN(visit_date)) as month1,
        EXTRACT(week from MIN(visit_date)) as week1,
        EXTRACT(day from MIN(visit_date)) as day1
    from sessions
    group by source
)

select
    source,
    month1,
    week1,
    day1,
    SUM(visitors_number) as visitor_number
from tab
group by source, month1, week1, day1
order by visitor_number desc;


/* Сколько лидов к нам приходят? */


select
    COUNT(lead_id) as number_of_leads,
    DATE(created_at) as day1
from leads
group by day1
order by day1

with tab1 as (
    select
        count(lead_id) as leads_count,
        date(created_at) as day1
    from leads
    group by day1
),

tab2 as (
    select
        count(visitor_id) as clicks,
        date(visit_date) as day2
    from sessions
    group by day2
)

select
    tab1.day1,
    round(
        tab1.leads_count * 100.00 / tab2.clicks, 1
    ) as clicks_to_lead_conversion
from tab1
inner join tab2
    on tab1.day1 = tab2.day2
order by tab1.day1


/* Какая конверсия из лида в оплату? */

with tab as (
    select
        count(lead_id) as leads_count,
        count(lead_id) filter (where amount <> 0) as
        payment_count,
        date(created_at) as day1
    from leads
    group by day1
)

select
    day1,
    round(
        payment_count * 100.00 / leads_count, 1
    ) as lead_to_payment_conversion
from tab
order by day1


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
    select
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
        tab.visit_date asc,
        tab.utm_source asc,
        tab.utm_medium asc,
        tab.utm_campaign asc
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
        tab2.last_date as date1,
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
),

tab6 as (
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
    utm_campaign asc)

select
    visit_date,
    utm_source as source,
    utm_medium as medium,
    utm_campaign as campaign,
    (coalesce(total_cost, 0) / visitors_count) as cpu,
    case
        when leads_count = 0 then 0 else
            coalesce(total_cost, 0) / leads_count
    end as cpl,
    case
        when purchases_count = 0 then 0 else
            coalesce(total_cost, 0) / purchases_count
    end as cppu,
    case
        when total_cost = 0 then 0 else
            (coalesce(revenue, 0) - total_cost) * 100 / total_cost
    end as roi
from tab6

/* Можно посчитать за сколько дней с момента перехода по рекламе закрывается 90% лидов. */

with tab as (
    select
        visitor_id,
        source as utm_source,
        medium as utm_medium,
        campaign as utm_campaign,
        MIN(visit_date) as visit_date
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
        l.amount desc nulls first,
        tab.visit_date asc,
        tab.utm_source asc,
        tab.utm_medium asc,
        tab.utm_campaign asc
),

tab2 as (
    select
        visitor_id,
        utm_source,
        utm_medium,
        utm_campaign,
        lead_id,
        (DATE(created_at) - DATE(visit_date)) as datediff
    from tab1
    where lead_id is not null
),

tab3 as (
    select
        datediff,
        COUNT(lead_id) as lead_count
    from tab2
    group by datediff
    order by datediff
),

tab4 as (
    select
        datediff,
        SUM(lead_count) over (order by datediff) as closed_leads
    from tab3
)

select
    datediff,
    ROUND(
        closed_leads * 100 / (select SUM(lead_count) from tab3), 0
    ) as closed_leads_percent
from tab4
