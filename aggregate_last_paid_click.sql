with tab1 as
(select visitor_id,
       visit_date,
       source as utm_source,
       medium as utm_medium,
       campaign as utm_campaign,
       row_number() over (partition by visitor_id order by visit_date desc) as rn
from sessions s
where medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')),


tab as
(select visitor_id,
       visit_date,
       utm_source,
       utm_medium,
       utm_campaign
from tab1
where rn = 1),

tab2 as
(select  tab.visitor_id,
		date(tab.visit_date) as visit_date,
		tab.utm_source,
		tab.utm_medium,
		tab.utm_campaign,
		case 
			when tab.visit_date <= l.created_at then l.lead_id
			else NULL			
		end as lead_id,
		case 
			when tab.visit_date <= l.created_at then l.created_at
			else NULL			
		end as created_at,
		case 
			when tab.visit_date <= l.created_at then l.amount
			else NULL			
		end as amount,
		case 
			when tab.visit_date <= l.created_at then l.closing_reason
			else NULL			
		end as closing_reason,
		case 
			when tab.visit_date <= l.created_at then l.status_id
			else NULL			
		end as status_id
from tab
left join leads l 
on l.visitor_id = tab.visitor_id
order by amount desc nulls last, date(visit_date), utm_source, utm_medium, utm_campaign),

tab3 as
((select ad_id, campaign_id, campaign_name, utm_source, utm_medium, utm_campaign, utm_content, date(campaign_date) as date, daily_spent from ya_ads ya)
union all
(select ad_id, campaign_id, campaign_name, utm_source, utm_medium, utm_campaign, utm_content, date(campaign_date) as date, daily_spent from vk_ads va)),

tab4 as
(select sum(daily_spent) as daily_spent,
       utm_source,
       utm_medium,
       utm_campaign,
       date
from tab3
group by utm_source, utm_medium, utm_campaign, date),

tab5 as
(select tab2.visitor_id, 
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
on tab2.utm_source = tab4.utm_source and tab2.utm_medium = tab4.utm_medium and tab2.utm_campaign = tab4.utm_campaign and tab2.visit_date = tab4.date)

select  visit_date,
        COUNT(visitor_id) as visitors_count,
		utm_source,
		utm_medium,
		utm_campaign,
		daily_spent as total_cost,
		COUNT(lead_id) as leads_count,
		COUNT(lead_id) filter (where status_id = 142) as purchases_count,
		SUM(amount) filter (where status_id = 142) as revenue
from tab5
group by visit_date,
		utm_source,
		utm_medium,
		utm_campaign,
		daily_spent
order by revenue desc nulls last, visit_date, visitors_count desc, utm_source, utm_medium, utm_campaign