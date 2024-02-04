with tab as
((select ad_id, campaign_id, campaign_name, utm_source, utm_medium, utm_campaign, utm_content, campaign_date, daily_spent from ya_ads ya)
union all
(select ad_id, campaign_id, campaign_name, utm_source, utm_medium, utm_campaign, utm_content, campaign_date, daily_spent from vk_ads va))

select s.visitor_id,
	   s.visit_date, 
	   tab.utm_source, 
	   tab.utm_medium, 
	   tab.utm_campaign, 
	   l.lead_id, 
	   l.created_at, 
	   l.amount, 
	   l.closing_reason,
	   l.status_id
from sessions s
left join tab 
on s.source = tab.utm_source and s.medium = tab.utm_medium and s.campaign = tab.utm_campaign and s.content = tab.utm_content
left join leads l 
on s.visitor_id = l.visitor_id 
where s.source like '_k' or s.source like '_andex' and l.created_at >= s.visit_date
order by l.amount desc nulls last, s.visit_date asc, tab.utm_source ASC, tab.utm_medium ASC, tab.utm_campaign ASC;