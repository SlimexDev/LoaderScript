print("Game ID:", game.GameId)
print("Place ID:", game.PlaceId)
if typeof(setclipboard) == "function" then
    setclipboard(tostring(game.GameId))
    print("Game ID copied to clipboard.")
end
