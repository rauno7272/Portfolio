--[[
    Client-side script for Custom Email
    Handles recipient selection from DB and message input.
]]

-- Local function to create and show the recipient selection menu using dynamic checkboxes
local function showRecipientDialog(accounts)
    if not accounts or #accounts == 0 then
        lib.notify({
            title = 'No Email Accounts Found',
            description = 'Could not find any email accounts in the database.',
            type = 'error'
        })
        return
    end

    -- Dynamically build a list of individual checkbox inputs
    local inputFields = {}
    for _, account in ipairs(accounts) do
        table.insert(inputFields, {
            type = 'checkbox',
            label = account.address,
            value = account.address -- Use the email as the value
        })
    end

    -- Show the input dialog with the dynamically created checkboxes
    local inputs = lib.inputDialog('Select Recipients', inputFields)

    if inputs then
        local selectedAccounts = {}
        -- The dialog returns a table of booleans. Iterate through them.
        for i, wasSelected in ipairs(inputs) do
            if wasSelected then
                -- The index 'i' corresponds to the account in our original list.
                -- We get the email address from the original 'accounts' table.
                table.insert(selectedAccounts, accounts[i].address)
            end
        end

        -- Check if the user selected at least one account
        if #selectedAccounts > 0 then
            -- When recipients are selected, open the email creation dialog
            openEmailDialog(selectedAccounts)
        else
            lib.notify({title = "No recipients selected", type = "info"})
        end
    end
end

-- This event is triggered by the server after it confirms the player has permission
RegisterNetEvent('customEmail:client:startEmailProcess', function()
    -- Show a "pre-menu" to ask the user what they want to do
    openSendMethodMenu()
end)

-- New function to show the sending method menu
function openSendMethodMenu()
    local inputs = lib.inputDialog('Select Send Method', {
        {type = 'select', label = 'How do you want to send this email?', options = {
            {label = 'Select Manually', value = 'manual'},
            {label = 'Send to ALL Accounts', value = 'all'}
        }, required = true}
    })

    if inputs then
        local sendMethod = inputs[1]
        if sendMethod == 'manual' then
            lib.notify({ title = 'Loading...', description = 'Fetching all email accounts...', type = 'info'})
            TriggerServerEvent('customEmail:server:getRecipientAccounts', 'manual')
        elseif sendMethod == 'all' then
            lib.notify({ title = 'Loading...', description = 'Fetching all email accounts...', type = 'info'})
            TriggerServerEvent('customEmail:server:getRecipientAccounts', 'all')
        end
    end
end

-- Event to receive the recipient list and call the local function
RegisterNetEvent('customEmail:client:showRecipientMenu', function(accounts)
    -- Call the local function to handle the menu display
    showRecipientDialog(accounts)
end)

-- New event handler for "Send to All"
RegisterNetEvent('customEmail:client:sendToAllAccounts', function(accounts)
    if not accounts or #accounts == 0 then
        lib.notify({ title = 'No accounts found', type = 'error'})
        return
    end

    local selectedAccounts = {}
    for _, account in ipairs(accounts) do
        table.insert(selectedAccounts, account.address)
    end

    lib.notify({ title = 'Accounts Loaded', description = ('Preparing email for %d recipients.'):format(#selectedAccounts), type = 'success'})
    openEmailDialog(selectedAccounts)
end)

-- Function to open the dialog for writing the email
function openEmailDialog(recipientEmails)
    -- Use ox_lib's input dialog to get the email details from the user
    local dialogTitle = 'New Email (' .. #recipientEmails .. ' recipients)'
    local inputs = lib.inputDialog(dialogTitle, {
        {type = 'input', label = 'Subject', placeholder = 'Enter email subject', required = true, min = 3, max = 50},
        {type = 'textarea', label = 'Message', placeholder = 'Enter your message here...', required = true, min = 5, max = 1000},
        {type = 'input', label = 'Image URL (Optional)', placeholder = 'https://i.imgur.com/image.png', required = false} -- New field for image URL
    })

    -- If the user provided inputs (didn't cancel), send the data to the server
    if inputs then
        local subject = inputs[1]
        local message = inputs[2]
        local imageUrl = inputs[3] -- Get the image URL from the new field
        
        -- Trigger the server event, passing the table of recipients and the new image URL
        TriggerServerEvent('customEmail:server:sendEmail', recipientEmails, subject, message, imageUrl)
    end
end

