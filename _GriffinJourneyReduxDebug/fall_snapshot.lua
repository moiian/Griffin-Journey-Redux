return function(M)
function M:snapshot()
    local last
    if self.last then last={};for k,v in pairs(self.last) do last[k]=v end end
    local passenger_last
    if self.passenger_last then passenger_last={};for k,v in pairs(self.passenger_last) do passenger_last[k]=v end end
    local start_counts={};for k,v in pairs(self.start_counts) do start_counts[k]=v end
    local start_last;if self.start_last then start_last={};for k,v in pairs(self.start_last) do start_last[k]=v end end
    return {enabled=self.enabled,calls=self.calls,attempts=self.attempts,errors=self.errors,last=last,status=self.status,
        start_calls=self.start_calls,passenger_start_calls=self.passenger_start_calls,start_counts=start_counts,start_last=start_last,hook_entries=self.hook_entries,
        passenger_calls=self.passenger_calls,passenger_attempts=self.passenger_attempts,passenger_errors=self.passenger_errors,passenger_last=passenger_last}
end
end
