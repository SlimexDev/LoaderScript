alocal __O1705lI=(__O1704lI and (((__O1704lI):FindFirstChildOfClass((__O1777lI)[959]) or (__O1704lI):WaitForChild((__O1777lI)[958],10))));
if (__O1705lI and (__O1705lI):IsA((__O1777lI)[960])) then
(__O1700lI)(__O1705lI);
end;
end;
local function __O1706lI()
if __O1693lI then
for __O1707lI,__O1708lI in (ipairs)((workspace):GetDescendants()) do
(__O1696lI)(__O1708lI);
end;
else
for __O1709lI in (pairs)(__O1694lI) do
(__O1696lI)(__O1709lI);
end;
end;
local __O1710lI=(__O68lI).Character;
local __O1711lI=(__O1710lI and (__O1710lI):FindFirstChildOfClass((__O1777lI)[961]));
if __O1711lI then
(__O1700lI)(__O1711lI);
end;
end;
(__O87lI):Section((__O1777lI)[962]);
(__O87lI):Toggle({Name=(__O1777lI)[963],Default=__O1693lI,Description=(__O1777lI)[964],Callback=function(__O1712lI)
__O1693lI=__O1712lI;
(__O1706lI)();
end});
local __O1714lI=((workspace).DescendantAdded):Connect(function(__O1713lI)
if __O1693lI then
(__O1696lI)(__O1713lI);
end;
end);
local __O1716lI=((__O68lI).CharacterAdded):Connect(function(__O1715lI)
((task).spawn)(__O1703lI,__O1715lI);
end);
(__O1706lI)();
(((__O7lI).Gui).Destroying):Connect(function()
(__O1714lI):Disconnect();
(__O1716lI):Disconnect();
for __O1717lI,__O1718lI in (pairs)(__O1695lI) do
for __O1719lI,__O1720lI in (ipairs)(__O1718lI) do
(__O1720lI):Disconnect();
end;
end;
__O1693lI=false;
(__O1706lI)();
end);
end;
do
local __O1721lI=true;
local __O1722lI=(game):GetService((__O1777lI)[965]);
(__O87lI):Section((__O1777lI)[966]);
(__O87lI):Toggle({Name=(__O1777lI)[967],Default=__O1721lI,Description=(__O1777lI)[968],Callback=function(__O1723lI)
__O1721lI=__O1723lI;
end});
local __O1724lI=((__O68lI).Idled):Connect(function()
if (not __O1721lI) then
return ;
end;
(pcall)(function()
(__O1722lI):CaptureController();
(__O1722lI):ClickButton2(((Vector2).new)());
end);
end);
(((__O7lI).Gui).Destroying):Connect(function()
(__O1724lI):Disconnect();
end);
end;
do
local __O1725lI=(__O1777lI)[969];
local __O1726lI=(game):GetService((__O1777lI)[970]);
local __O1727lI=(game):GetService((__O1777lI)[971]);
local __O1728lI=((getgenv and (getgenv)()) or {});
local __O1729lI=(((((((type)(syn) == (__O1777lI)[973]) and (syn).queue_on_teleport)) or queue_on_teleport) or queueonteleport) or ((((type)(fluxus) == (__O1777lI)[972]) and (fluxus).queue_on_teleport)));
local __O1730lI={AutoRejoin=false,AutoLoad=((__O140lI).IsPremium)(),Delay=5,Rejoining=false,Alive=true};
local function __O1731lI()
local __O1732lI=(__O1728lI).SlimeHubLoader;
local __O1733lI=(((((type)(__O1732lI) == (__O1777lI)[978]) and (__O1732lI ~= (__O1777lI)[977])) and __O1732lI) or ((__O1777lI)[976] .. (((string).format)((__O1777lI)[975],__O1725lI) .. (__O1777lI)[974])));
return ((__O1777lI)[984] .. ((__O1777lI)[983] .. ((__O1777lI)[982] .. ((__O1777lI)[981] .. ((__O1777lI)[980] .. (__O1733lI .. (__O1777lI)[979]))))));
end;
local function __O1734lI()
if ((not (__O1730lI).AutoLoad) or (not __O1729lI)) then
return false;
end;
return ((pcall)(__O1729lI,(__O1731lI)()));
end;
local function __O1735lI(__O1736lI)
if (__O1730lI).Rejoining then
return ;
end;
(__O1730lI).Rejoining=true;
(__O1734lI)();
((task).spawn)(function()
while ((__O1730lI).Rejoining and (__O1730lI).Alive) do
if (__O1736lI and ((game).JobId ~= (__O1777lI)[985])) then
(pcall)((__O1726lI).TeleportToPlaceInstance,__O1726lI,(game).PlaceId,(game).JobId,__O68lI);
else
(pcall)((__O1726lI).Teleport,__O1726lI,(game).PlaceId,__O68lI);
end;
((task).wait)(10);
__O1736lI=false;
end;
end);
end;
local function __O1737lI()
if (((not (__O1730lI).AutoRejoin) or (__O1730lI).Rejoining) or (__O1730lI).Pending) then
return ;
end;
(__O1730lI).Pending=true;
((task).delay)((__O1730lI).Delay,function()
(__O1730lI).Pending=false;
if ((__O1730lI).AutoRejoin and (__O1730lI).Alive) then
(__O1735lI)(false);
end;
end);
end;
local __O1738lI={};
((table).insert)(__O1738lI,((__O68lI).OnTeleport):Connect(function(__O1739lI)
if (__O1739lI == ((Enum).TeleportState).Started) then
(__O1734lI)();
end;
end));
(pcall)(function()
((table).insert)(__O1738lI,((__O1727lI).ErrorMessageChanged):Connect(function(__O1740lI)
if (((type)(__O1740lI) == (__O1777lI)[987]) and (__O1740lI ~= (__O1777lI)[986])) then
(__O1737lI)();
end;
end));
end);
((task).spawn)(pcall,function()
local __O1741lI=(((game):GetService((__O1777lI)[990])):WaitForChild((__O1777lI)[989],5)):WaitForChild((__O1777lI)[988],5);
if ((not __O1741lI) or (not (__O1730lI).Alive)) then
return ;
end;
((table).insert)(__O1738lI,((__O1741lI).ChildAdded):Connect(function(__O1742lI)
if ((__O1742lI).Name == (__O1777lI)[991]) then
(__O1737lI)();
end;
end));
end);
(__O87lI):Section((__O1777lI)[992]);
((__O140lI).PremiumToggle)(__O87lI,(__O1777lI)[993],{Name=(__O1777lI)[994],Default=(__O1730lI).AutoRejoin,Description=(__O1777lI)[995],Callback=function(__O1743lI)
(__O1730lI).AutoRejoin=__O1743lI;
if (not __O1743lI) then
(__O1730lI).Rejoining=false;
end;
end});
(__O87lI):Slider({Name=(__O1777lI)[996],Description=(__O1777lI)[997],Min=0,Max=60,Increment=1,Default=(__O1730lI).Delay,Suffix=(__O1777lI)[998],Callback=function(__O1744lI)
(__O1730lI).Delay=__O1744lI;
end});
((__O140lI).PremiumToggle)(__O87lI,(__O1777lI)[999],{Name=(__O1777lI)[1000],Default=(__O1730lI).AutoLoad,Description=(__O1777lI)[1001],Callback=function(__O1745lI)
(__O1730lI).AutoLoad=__O1745lI;
if (__O1745lI and (not __O1729lI)) then
(__O7lI):Notify({Title=(__O1777lI)[1002],Content=(__O1777lI)[1003],Type=(__O1777lI)[1004],Duration=5});
end;
end});
(__O87lI):Button({Name=(__O1777lI)[1005],ButtonText=(__O1777lI)[1006],Icon=(__O1777lI)[1007],Description=(__O1777lI)[1008],Callback=function()
(__O1735lI)(true);
end});
(((__O7lI).Gui).Destroying):Connect(function()
(__O1730lI).Alive,(__O1730lI).Rejoining=false,false;
for __O1746lI,__O1747lI in (ipairs)(__O1738lI) do
(__O1747lI):Disconnect();
end;
end);
end;
do
local __O1748lI=(__O1777lI)[1009];
local __O1749lI=(game):GetService((__O1777lI)[1010]);
local __O1750lI=true;
local __O1751lI=false;
local __O1752lI;
local function __O1753lI()
local __O1754lI={};
for __O1755lI,__O1756lI in (pairs)((__O1lI).Flags) do
(__O1754lI)[__O1755lI]=((((typeof)(__O1756lI) == (__O1777lI)[1011]) and (tostring)(__O1756lI)) or __O1756lI);
end;
local __O1757lI,__O1758lI=(pcall)((__O1749lI).JSONEncode,__O1749lI,__O1754lI);
return ((__O1757lI and __O1758lI) or nil);
end;
local function __O1759lI()
if (not (__O7lI).SaveConfig) then
return false;
end;
local __O1760lI=(__O7lI):SaveConfig(__O1748lI);
if __O1760lI then
__O1752lI=(__O1753lI)();
end;
return __O1760lI;
end;
(__O87lI):Section((__O1777lI)[1012]);
(__O87lI):Toggle({Name=(__O1777lI)[1013],Default=__O1750lI,Description=(__O1777lI)[1014],Callback=function(__O1761lI)
__O1750lI=__O1761lI;
if __O1751lI then
(__O1759lI)();
end;
end});
(__O87lI):Button({Name=(__O1777lI)[1015],ButtonText=(__O1777lI)[1016],Icon=(__O1777lI)[1017],Callback=function()
local __O1762lI=(__O1759lI)();
(__O7lI):Notify({Title=(__O1777lI)[1018],Content=((__O1762lI and (__O1777lI)[1020]) or (__O1777lI)[1019]),Type=((__O1762lI and (__O1777lI)[1022]) or (__O1777lI)[1021]),Duration=3});
end});
local __O1763lI={};
local function __O1764lI(__O1765lI)
return ((((type)(__O1765lI) == (__O1777lI)[1023]) and ((table).clone)(__O1765lI)) or __O1765lI);
end;
(__O87lI):Button({Name=(__O1777lI)[1024],ButtonText=(__O1777lI)[1025],Icon=(__O1777lI)[1026],Description=(__O1777lI)[1027],Callback=function()
local __O1766lI=0;
for __O1767lI,__O1768lI in (pairs)(__O1763lI) do
local __O1769lI=((__O1lI).Options)[__O1767lI];
if ((__O1769lI and (__O1769lI).Set) and (not (pcall)((__O1769lI).Set,__O1769lI,(__O1764lI)(__O1768lI)))) then
__O1766lI+=1;
end;
end;
__O1750lI=((__O1763lI)[(__O1777lI)[1028]] ~= false);
local __O1770lI=(__O1759lI)();
if (not __O1770lI) then
local __O1771lI=((((__O1lI).Folder or (__O1777lI)[1031])) .. ((__O1777lI)[1030] .. (__O1748lI .. (__O1777lI)[1029])));
__O1770lI=(pcall)(function()
if (isfile)(__O1771lI) then
(delfile)(__O1771lI);
end;
end);
end;
(__O7lI):Notify({Title=(__O1777lI)[1032],Content=(((__O1766lI == 0) and (__O1777lI)[1034]) or ((__O1766lI .. (__O1777lI)[1033]))),Type=((((__O1766lI == 0) and __O1770lI) and (__O1777lI)[1036]) or (__O1777lI)[1035]),Duration=3});
end});
for __O1772lI,__O1773lI in (pairs)((__O1lI).Flags) do
(__O1763lI)[__O1772lI]=(__O1764lI)(__O1773lI);
end;
if (__O7lI).LoadConfig then
(pcall)((__O7lI).LoadConfig,__O7lI,__O1748lI);
end;
((task).delay)(1,function()
__O1751lI=true;
end);
local __O1774lI=0;
local __O1776lI=((__O64lI).Heartbeat):Connect(function()
if (((not __O1751lI) or (not __O1750lI)) or (((os).clock)() < __O1774lI)) then
return ;
end;
__O1774lI=(((os).clock)() + 2);
local __O1775lI=(__O1753lI)();
if (__O1775lI and (__O1775lI ~= __O1752lI)) then
(__O1759lI)();
end;
end);
(((__O7lI).Gui).Destroying):Connect(function()
(__O1776lI):Disconnect();
end);
end;
(__O7lI):SelectTab((__O1777lI)[1037]);
(__O7lI):Notify({Title=(__O1777lI)[1038],Content=(__O1777lI)[1039],Type=(__O1777lI)[1040],Duration=4});
