with tab as
(select distinct on(visitor_id) 
					visitor_id,
					max(visit_date) as visit_date,
					source as utm_source,
					medium as utm_medium,
					campaign as utm_campaign,
					content as utm_content
from sessions s
where medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
group by visitor_id, utm_source, utm_medium, utm_campaign, utm_content),

tab1 as
(select tab.visitor_id,
		tab.visit_date,
		tab.utm_source,
		tab.utm_medium,
		tab.utm_campaign,
		tab.utm_content,
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
order by amount desc nulls last, visit_date, utm_source, utm_medium, utm_campaign),

tab2 as
((select ad_id, campaign_id, campaign_name, utm_source, utm_medium, utm_campaign, utm_content, campaign_date, daily_spent from ya_ads ya)
union all
(select ad_id, campaign_id, campaign_name, utm_source, utm_medium, utm_campaign, utm_content, campaign_date, daily_spent from vk_ads va)),

tab3 as
(select tab1.visitor_id, date(tab1.visit_date) as visit_date, tab1.utm_source, tab1.utm_medium, tab1.utm_campaign, tab1.utm_content, tab1.lead_id, 
date(tab1.created_at) as created_at, tab1.amount, tab1.closing_reason, tab1.status_id, tab2.ad_id, tab2.campaign_id, tab2.campaign_name, date(tab2.campaign_date) as campaign_date, tab2.daily_spent
from tab1
left join tab2
on tab1.utm_source = tab2.utm_source and tab1.utm_medium = tab2.utm_medium and tab1.utm_campaign = tab2.utm_campaign and tab1.utm_content = tab2.utm_content),

tab4 as
(select visit_date,
		utm_source,
		utm_medium,
		utm_campaign,
		COUNT(visitor_id) as visitors_count,
		SUM(daily_spent) as total_cost,
		COUNT(lead_id) as leads_count
from tab3
group by visit_date,
		utm_source,
		utm_medium,
		utm_campaign),
		
tab5 as
(select visit_date,
		utm_source,
		utm_medium,
		utm_campaign,
		COUNT(lead_id) as purchases_count,
		SUM(amount) as revenue
from tab3
group by visit_date,
		utm_source,
		utm_medium,
		utm_campaign,
		status_id
having status_id = 142)

select tab4.visit_date, tab4.visitors_count, tab4.utm_source, tab4.utm_medium, tab4.utm_campaign, tab4.total_cost, tab4.leads_count,
		tab5.purchases_count, tab5.revenue
from tab4
left join tab5
on tab4.visit_date = tab5.visit_date and tab4.utm_source = tab5.utm_source and tab4.utm_medium = tab5.utm_medium and tab4.utm_campaign = tab5.utm_campaign
order by tab5.revenue desc nulls last, tab4.visit_date, tab4.visitors_count desc, tab4.utm_source, tab4.utm_medium, tab4.utm_campaign;