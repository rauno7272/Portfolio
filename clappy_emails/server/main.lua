--[[
    Server-side script for Custom Email
    Handles permissions, DB queries, and sending emails via lb-phone.
]]

-- Register the command on the server and restrict it to a specific ACE permission.
RegisterCommand(Config.SendCommand, function(source, args, rawCommand)
    -- Because the command is restricted via the 'true' flag below, this code will
    -- only run for players who have the required permission.
    -- The permission needed is 'command.customemail' (or whatever Config.SendCommand is).
    TriggerClientEvent('customEmail:client:startEmailProcess', source)
end, true) -- The 'true' flag restricts the command to authorized users.

-- Event to get all email accounts from the database and send them to the client
RegisterNetEvent('customEmail:server:getRecipientAccounts', function(sendMethod)
    local src = source
    -- Fetch all email addresses from the phone_mail_accounts table
    local result = MySQL.query.await('SELECT address FROM phone_mail_accounts', {})
    
    if not result or #result == 0 then
        lib.notify(src, { title = 'No Email Accounts Found', type = 'error'})
        return
    end
    
    if sendMethod == 'manual' then
        -- Send the list to the client for manual selection
        TriggerClientEvent('customEmail:client:showRecipientMenu', src, result)
    elseif sendMethod == 'all' then
        -- Send the list to the client to be auto-selected
        TriggerClientEvent('customEmail:client:sendToAllAccounts', src, result)
    end
end)

-- Event to receive email data from a client and send it to multiple recipients
RegisterNetEvent('customEmail:server:sendEmail', function(recipientEmails, subject, message, imageUrl)
    local src = source
    local playerName = GetPlayerName(src)

    -- Permission is already checked by the restricted command, so this is a failsafe.
    if not IsPlayerAceAllowed(src, 'command.' .. Config.SendCommand) then
        print(('[CustomEmail] Unauthorized attempt to send email by player %s.'):format(playerName))
        return
    end

    -- Ensure recipientEmails is a table and has entries
    if not recipientEmails or type(recipientEmails) ~= 'table' or #recipientEmails == 0 then
        return
    end
    
    -- Loop through each recipient email and send the mail
    for _, recipientEmail in ipairs(recipientEmails) do
        local mailData = {
            sender = Config.SenderName,
            to = recipientEmail,
            subject = subject,
            message = message,
        }

        -- If an image URL was provided, add it to the attachments table
        if imageUrl and imageUrl ~= '' then
            mailData.attachments = { imageUrl }
        end
        
        -- Use the lb-phone export to send the email
        exports["lb-phone"]:SendMail(mailData)
    end

    -- Notify the sender that the emails have been sent
    lib.notify(src, {
        title = 'Email Sent',
        description = ('Your message has been sent to %d recipients.'):format(#recipientEmails),
        type = 'success'
    })
end)

