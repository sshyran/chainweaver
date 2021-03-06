{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE RecursiveDo #-}

-- | Dialog for exporting the entire storage to the user
module Frontend.UI.Dialogs.ExportWallet
  ( uiExportWalletDialog
  ) where

import Control.Monad.Fix (MonadFix)
import Reflex.Dom.Core
import Data.Text (Text)
import qualified Data.Text as T

import Frontend.AppCfg
import Frontend.UI.Modal.Impl
import Frontend.Foundation
import Frontend.UI.Widgets
import Frontend.UI.Widgets.Helpers (dialogSectionHeading)

uiExportWalletDialog
  :: ( DomBuilder t m, MonadFix m, MonadHold t m, PostBuild t m, Monoid mConf, Flattenable mConf t
     )
  => ExportWallet t m
  -> Event t ()
  -> m (mConf, Event t ())
uiExportWalletDialog exportWallet _onCloseExternal = mdo
  onClose <- modalHeader $ dynText dTitle
  (dTitle, (conf, closes)) <- fmap splitDynPure . splitDynPure <$> workflow (uiExportWalletScreen exportWallet onClose)
  mConf <- flatten =<< tagOnPostBuild conf
  let close = switch $ current closes
  pure (mConf, close <> onClose)

uiExportWalletScreen
  :: (DomBuilder t m, PostBuild t m, Monoid mConf, MonadFix m, MonadHold t m)
  => ExportWallet t m -> Event t () -> Workflow t m (Text, (mConf, Event t ()))
uiExportWalletScreen (ExportWallet _exportWallet_requestExport) onClose = Workflow $ mdo
  pw <- modalMain $ do
    dialogSectionHeading mempty "Notice"
    divClass "group" $ do
      el "p" $ text
        "Exporting wallet data will generate an encrypted file containing sensitive and \
        \non-sensitive information available within the wallet. The file will be protected\
        \ by the wallet password that was in use at time of export. Store this file in a \
        \secure location and do not alter its contents."

      elClass "p" "export-wallet__contents-includes" $ text "The wallet data to be exported within this file includes:"
      elClass "ul" "export-wallet__contents-list" $ do
        el "li" $ text "Generated public/private key pairs"
        el "li" $ text "Added accounts"
        el "li" $ text "Account notes"
        el "li" $ text "Network configuration"
        el "li" $ text "Transaction configuration"

    dialogSectionHeading mempty "Current Password"
    divClass "group" $ do
      pw' <- uiPassword "password-input__wrapper" "password-input" "Enter current password"
      widgetHold_ blank $ ffor eErr $ elClass "p" "error_inline" . text . \case
        ExportWalletError_FileNotWritable fp -> "Could not write file to " <> fp
        ExportWalletError_PasswordIncorrect -> "Password Incorrect"
        ExportWalletError_NoKeys -> "This wallet has no keys yet and cannot be exported"
        ExportWalletError_CommandLogExport -> "Unable to export transaction logs"
        ExportWalletError_UpgradeFailed -> "Wallet data is out of date and could not be upgraded. Please back up wallet data manually"
      pure pw'

  eSubmit <- modalFooter $
      confirmButton def "Export Wallet"

  (eErr, eOk) <- fmap fanEither . _exportWallet_requestExport $ (current $ value pw) <@ eSubmit
  pure ( ( "Export Wallet Data"
         , (mempty, onClose)
         )
       , uiExportWalletSuccess onClose <$> eOk
       )

uiExportWalletSuccess
  :: (DomBuilder t m, PostBuild t m, Monoid mConf)
  => Event t () -> FilePath -> Workflow t m (Text, (mConf, Event t ()))
uiExportWalletSuccess onClose filePath = Workflow $ do
  modalMain $ do
    elClass "div" "modal__success_screen" $ do
      el "p" $ elClass "i" "fa fa-check-circle" $ blank
      el "p" $ text $ "Exported wallet to"
      el "p" $ text $ T.pack filePath

  done <- modalFooter $ do
    confirmButton def "Close"

  pure (("Export Wallet Success", (mempty, onClose <> done)), never)
