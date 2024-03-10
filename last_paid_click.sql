with tab as
(select distinct on(visitor_id) visitor_id,
	   max(visit_date) as visit_date,
	   source as utm_source,
	   medium as utm_medium,
	   campaign as utm_campaign
from sessions s
where medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
group by visitor_id, utm_source, utm_medium, utm_campaign)

select tab.visitor_id,
		tab.visit_date,
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
order by amount desc nulls last, visit_date, utm_source, utm_medium, utm_campaign;