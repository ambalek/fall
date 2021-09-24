local Text = {
  get_text_or_call = function(value, arg)
    if type(value) == "function" then
      return value(arg)
    elseif value then
      return value
    end
  end
}

return Text