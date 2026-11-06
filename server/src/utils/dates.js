const config = require('../config');

/** Return `YYYY-MM-DD` for `date` as seen in the configured app time zone. */
function dateInTimeZone(date = new Date(), timeZone = config.appTimezone) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);

  const value = (type) => parts.find((part) => part.type === type).value;
  return `${value('year')}-${value('month')}-${value('day')}`;
}

/** Day of week (0 = Sunday) for `date` in the configured app time zone. */
function dayOfWeekInTimeZone(date = new Date(), timeZone = config.appTimezone) {
  return new Date(`${dateInTimeZone(date, timeZone)}T00:00:00Z`).getUTCDay();
}

module.exports = { dateInTimeZone, dayOfWeekInTimeZone };
