with tab as
((select ad_id, campaign_id, campaign_name, utm_source, utm_medium, utm_campaign, utm_content, campaign_date, daily_spent from ya_ads ya)
union all
(select ad_id, campaign_id, campaign_name, utm_source, utm_medium, utm_campaign, utm_content, campaign_date, daily_spent from vk_ads va)),

tab1 as
(select *, s.visitor_id as visitor
from sessions s
left join tab 
on s.source = tab.utm_source and s.medium = tab.utm_medium and s.campaign = tab.utm_campaign and s.content = tab.utm_content
left join leads l 
on s.visitor_id = l.visitor_id 
where s.source like '_k' or s.source like '_andex' and l.created_at >= s.visit_date),

tab2 as
(select visit_date,
	   utm_source,
	   utm_medium, 
	   utm_campaign,
	   COUNT(lead_id) as purchases_count,
	   SUM(amount) as revenue
from tab1
group by visit_date, utm_source, utm_medium, utm_campaign, tab1.status_id
having tab1.status_id = 142),

tab3 as
(select visit_date,
	   utm_source,
	   utm_medium, 
	   utm_campaign,
	   COUNT(visitor) as visitors_count,
	   SUM(daily_spent) as total_cost,
	   COUNT(lead_id) as leads_count
from tab1
group by visit_date, utm_source, utm_medium, utm_campaign)

select tab3.visit_date, 
       tab3.utm_source, 
       tab3.utm_medium, 
       tab3.utm_campaign, 
       tab3.visitors_count,
       tab3.total_cost,
       tab3.leads_count,
       tab2.purchases_count,
       tab2.revenue
from tab2
join tab3
on tab2.visit_date = tab3.visit_date
order by tab2.revenue desc nulls last, tab3.visit_date asc, tab3.visitors_count desc, tab3.utm_source ASC, tab3.utm_medium ASC,tab3.utm_campaign ASC;