{{ config(
    materialized='table'
) }}

with customers as (
    -- Pull raw or staged customer data from Snowflake
    select 
        id as customer_id,
        first_name,
        last_name
    from {{ source('hevo_raw', 'raw_customers') }} 
),

orders as (
    -- Pull raw or staged orders data
    select 
        id as order_id,
        user_id as customer_id,
        order_date
    from {{ source('hevo_raw', 'raw_orders') }}
),

payments as (
    -- Pull raw or staged payments data
    select 
        id as payment_id,
        order_id,
        amount
    from {{ source('hevo_raw', 'raw_payments') }}
),

customer_orders as (
    -- Aggregate order dates and count per customer
    select
        customer_id,
        min(order_date) as first_order,
        max(order_date) as most_recent_order,
        count(order_id) as number_of_orders
    from orders
    group by 1
),

customer_payments as (
    -- Calculate lifetime value by joining orders to their payment amounts
    select
        orders.customer_id,
        sum(payments.amount) as customer_lifetime_value
    from payments
    left join orders on payments.order_id = orders.order_id
    group by 1
),

final as (
    -- Combine everything into the final requested layout
    select
        customers.customer_id,
        customers.first_name,
        customers.last_name,
        customer_orders.first_order,
        customer_orders.most_recent_order,
        coalesce(customer_orders.number_of_orders, 0) as number_of_orders,
        coalesce(customer_payments.customer_lifetime_value, 0) as customer_lifetime_value
    from customers
    left join customer_orders on customers.customer_id = customer_orders.customer_id
    left join customer_payments on customers.customer_id = customer_payments.customer_id
)

select * from final
