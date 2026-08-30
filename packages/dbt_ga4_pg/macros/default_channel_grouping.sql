{#-
    Default channel grouping — Google's rules:
    https://support.google.com/analytics/answer/9756891
    Postgres port of the upstream BigQuery macro: REGEXP_CONTAINS(x, r"...") → (x ~ '...').
    NULL semantics match: in both engines a NULL operand makes the comparison NULL,
    which the CASE treats as "not matched" and falls through.
-#}
{% macro default_channel_grouping(source, medium, source_category, campaign) %}
case
  when (
      {{ source }} is null
        and {{ medium }} is null
    )
    or (
      {{ source }} = '(direct)'
      and ({{ medium }} = '(none)' or {{ medium }} = '(not set)')
    )
    then 'Direct'

  when {{ campaign }} ~ 'cross-network'
    then 'Cross-network'

  when (
      {{ source_category }} = 'SOURCE_CATEGORY_SHOPPING'
      or {{ campaign }} ~ '^(.*(([^a-df-z]|^)shop|shopping).*)$'
    )
    and {{ medium }} ~ '^(.*cp.*|ppc|retargeting|paid.*)$'
    then 'Paid Shopping'

  when {{ source_category }} = 'SOURCE_CATEGORY_SEARCH'
    and {{ medium }} ~ '^(.*cp.*|ppc|retargeting|paid.*)$'
    then 'Paid Search'

  when {{ source_category }} = 'SOURCE_CATEGORY_SOCIAL'
    and {{ medium }} ~ '^(.*cp.*|ppc|retargeting|paid.*)$'
    then 'Paid Social'

  when {{ source_category }} = 'SOURCE_CATEGORY_VIDEO'
    and {{ medium }} ~ '^(.*cp.*|ppc|retargeting|paid.*)$'
    then 'Paid Video'

  when {{ medium }} in ('display', 'banner', 'expandable', 'interstitial', 'cpm')
    then 'Display'

  when {{ medium }} ~ '^(.*cp.*|ppc|retargeting|paid.*)$'
    then 'Paid Other'

  when {{ source_category }} = 'SOURCE_CATEGORY_SHOPPING'
    or {{ campaign }} ~ '^(.*(([^a-df-z]|^)shop|shopping).*)$'
    then 'Organic Shopping'

  when {{ source_category }} = 'SOURCE_CATEGORY_SOCIAL'
    or {{ medium }} in ('social', 'social-network', 'social-media', 'sm', 'social network', 'social media')
    then 'Organic Social'

  when {{ source_category }} = 'SOURCE_CATEGORY_VIDEO'
    or {{ medium }} ~ '^(.*video.*)$'
    then 'Organic Video'

  when {{ source_category }} = 'SOURCE_CATEGORY_SEARCH' or {{ medium }} = 'organic'
    then 'Organic Search'

  when {{ medium }} in ('referral', 'app', 'link')
    then 'Referral'

  when {{ source }} ~ 'email|e-mail|e_mail|e mail'
    or {{ medium }} ~ 'email|e-mail|e_mail|e mail'
    then 'Email'

  when {{ medium }} = 'affiliate'
    then 'Affiliates'

  when {{ medium }} = 'audio'
    then 'Audio'

  when {{ source }} = 'sms'
    or {{ medium }} = 'sms'
    then 'SMS'

  when {{ medium }} ~ 'push$'
    or {{ medium }} ~ 'mobile|notification'
    or {{ source }} = 'firebase'
    then 'Mobile Push Notifications'

  else 'Unassigned'
end
{% endmacro %}