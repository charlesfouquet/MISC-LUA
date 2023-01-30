--[[
 * ReaScript Name: Trieur de fichiers / File sorter
 * About: Remplacement des chaînes de caractères dans les régions pour que les fichiers soient rendus et triés dans les dossiers appropriés
 * Instructions: Lancer le script, préciser le dossier d'export, vérifier les paramètres d'export, puis exporter. Retour en arrière une fois export terminé.
 * Author: Charles Fouquet
 * Author email: fouquetcharles@gmail.com
 * REAPER: 6.43
 * Version: 1.0
--]]

--Fonction s'occupant de Undo une fois le script exécuté
function continueRestOfTheScript()
  reaper.Main_OnCommand(40029, 0) --ID de commande correspondant à l'action "Undo" dans Reaper, équivalent à un Ctrl+Z ou Cmd+Z au clavier
end

--Fonction permettant d'attendre la fin de l'export
function checkIfRenderComplete()
  if reaper.JS_Window_FindTop('Render to File', true) then
    reaper.defer(checkIfRenderComplete) --nouvelle tentative en boucle
  else
    continueRestOfTheScript() --appel de la fonction s'occupant du Undo
  end
end

--Début du bloc du Undo
reaper.Undo_BeginBlock()

--Récupération de données dépendant de la session ouverte et de sa localisation sur disque
--OS pour paramétrage du séparateur de chemin d'accès
if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then
    separator = "\\"
  else
    separator = "/"
  end
--Date d'enregistrement depuis le chemin d'accès de la session
project_path = reaper.GetProjectPath()
recording_date = string.match(project_path, separator .. "(%d%d%d%d%d%d%d%d)" .. separator)
--Comedien depuis le nom de la piste sélectionnée
_, track_name = reaper.GetTrackName(reaper.GetSelectedTrack(0, 0))
actor_name = string.match(track_name, "@(%a+)")

--Récupération du nombre total de régions et marqueurs pour stockage et utilisation ultérieure
retval, num_markers, num_regions = reaper.CountProjectMarkers( proj )
num_total = retval

--[[
Du premier marqueur/de la première région de la session jusqu'à la fin,
récupération du nom de région uniquement si est une région, 
extraction du nom du personnage depuis le nom contenu dans la région,
formattage du nouveau nom de région contenant date d'enregistrement, comédien, personnage et nom de fichier,
injection d'une version compressée des données récupérées dans le nom de la région
]]--
for index = 0, num_total do
  local ret, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(index)
  if isrgn==true then
    stringstart, character_name, stringend = string.match(name, "(%d%d%d%d%d%d_)(.+)(_.+)")
    newname = "name=" .. name .. ";char=" .. character_name .. ";actor=" .. actor_name .. ";date=" .. recording_date
    reaper.SetProjectMarker(markrgnindexnumber, true, pos, rgnend, newname)
  end
end

--[[
Changement des paramètres d'export pour que les fichiers puissent être rendus au bon endroit au bon format:
 - Sélection des wildcards adéquates pour création de l'arborescence d'export et nommage correct
 - Sélection de l'option "Selected tracks (stems)" en tant que Source
 - Sélection de l'option "Project regions" en tant que Bounds (limites début fin de chaque fichier)
 - Décochage systématique de la case "Tail" rajoutant par défaut 1s de blanc à chaque fichier
 - Sélection systématique d'un export en Mono
]]--
reaper.GetSetProjectInfo_String( 0, "RENDER_PATTERN", "$region(date)[;]" .. separator .. "$region(actor)[;]" .. separator .. "$region(char)[;]" .. separator .. "$region(name)[;]", true)
reaper.GetSetProjectInfo( 0, "RENDER_SETTINGS", 3, true) --Source: Selected tracks (stems)
reaper.GetSetProjectInfo( 0, "RENDER_BOUNDSFLAG", 3, true) --Bounds: Project regions
reaper.GetSetProjectInfo( 0, "RENDER_TAILFLAG", 0, true) --Tail: décoché
reaper.GetSetProjectInfo( 0, "RENDER_CHANNELS", 1, true) --Canaux: Mono

--Ouverture de la fenêtre de rendu de Reaper
reaper.Main_OnCommand(40015, 0) --ID de commande correspondant à l'action "Ouvrir la fenêtre de rendu" dans Reaper

--Attente de la fermeture de la fenêtre de rendu, automatique une fois les fichiers exportés
checkIfRenderComplete()

--Fin du bloc du Undo, tout Ctrl+Z ou Cmd+Z annulera l'intégralité des actions du script en un seul coup de raccourci
reaper.Undo_EndBlock("Trieur de fichiers", -1)
