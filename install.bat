for %%x in (_retail_ _classic_ _ptr_) do (
echo Installing for %%x
xcopy /i /y Mama\*.* "C:\Program Files (x86)\World of Warcraft\%%x\Interface\Addons\Mama"
)
