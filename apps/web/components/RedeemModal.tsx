import React, {
  ReactNode,
  useState,
  Fragment,
  ChangeEvent,
  MouseEvent,
} from "react";
import { Dialog, Transition } from "@headlessui/react";
import {
  useAccount,
  useConnect,
  useContractRead,
  useContractReads,
  useContractWrite,
  usePrepareContractWrite,
} from "wagmi";
import ERC20 from "../../../packages/contracts/out/ERC20.sol/ERC20.json";
import Vault from "../../../packages/contracts/out/AIMVault.sol/AIMVault.json";

const RedeemModal = ({
  vault,
  underlying,
}: {
  vault: string;
  underlying: string;
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const [redeem, setRedeem] = useState("0");

  const { address } = useAccount();
  const { data: ConnectData } = useConnect();

  const confirmationNo = ConnectData?.chain.id === 5 ? 1 : 3;

  const { data } = useContractReads({
    contracts: [
      {
        addressOrName: underlying,
        contractInterface: ERC20.abi,
        functionName: "name",
      },
      {
        addressOrName: underlying,
        contractInterface: ERC20.abi,
        functionName: "balanceOf",
        args: address,
      },
      {
        addressOrName: vault,
        contractInterface: Vault.abi,
        functionName: "balanceOf",
        args: address,
      },
      {
        addressOrName: vault,
        contractInterface: Vault.abi,
        functionName: "updateTotalStrategyHoldings",
      },
    ],
    watch: true,
    onSettled(data, error) {
      if (error) console.log("error", error);
      console.log("allownace", data);
    },
  });

  const { data: assetsAmount } = useContractRead({
    addressOrName: vault,
    contractInterface: Vault.abi,
    functionName: "previewRedeem",
    args: data?.[2],
    onSettled(data, error) {
      if (error) console.log("error", error);

      console.log("vault bal", data?.toString());
    },
  });

  const { config: redeemConfig } = usePrepareContractWrite({
    addressOrName: vault,
    contractInterface: Vault.abi,
    functionName: "redeem",
    args: [parseInt(redeem), address, address],
    onSettled(data, error) {
      if (error) console.log("error", error);

      console.log("redeem config", data);
    },
  });
  const { write: redeemWrite } = useContractWrite({
    ...redeemConfig,
    onSettled(data, error) {
      if (error) console.log("error", error);

      console.log("deposited", data);
      data?.wait(confirmationNo).then((res) => console.log("confirmed", res));
    },
  });

  const closeModal = () => {
    setRedeem("0");
    setIsOpen(false);
  };

  const openModal = () => {
    setIsOpen(true);
  };

  const handleChange = (e: ChangeEvent<HTMLInputElement>) => {
    const amount = e.target.value;

    setRedeem(amount);
  };

  const handleRedeem = () => {
    console.log("redeem");
    redeemWrite?.();
  };

  const setMaxAmount = () => {
    data?.[2] && setRedeem(data[2].toString());
  };

  return (
    <>
      <div className="">
        <button
          className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-3 rounded"
          onClick={openModal}
        >
          Redeem
        </button>
      </div>

      <Transition appear show={isOpen} as={Fragment}>
        <Dialog as="div" className="relative z-10" onClose={closeModal}>
          <Transition.Child
            as={Fragment}
            enter="ease-out duration-300"
            enterFrom="opacity-0"
            enterTo="opacity-100"
            leave="ease-in duration-200"
            leaveFrom="opacity-100"
            leaveTo="opacity-0"
          >
            <div className="fixed inset-0 bg-black bg-opacity-25" />
          </Transition.Child>

          <div className="fixed inset-0 overflow-y-auto">
            <div className="flex min-h-full items-center justify-center p-4 text-center">
              <Transition.Child
                as={Fragment}
                enter="ease-out duration-300"
                enterFrom="opacity-0 scale-95"
                enterTo="opacity-100 scale-100"
                leave="ease-in duration-200"
                leaveFrom="opacity-100 scale-100"
                leaveTo="opacity-0 scale-95"
              >
                <Dialog.Panel className="w-1/3 max-w-md transform overflow-hidden rounded-2xl bg-white p-4 text-left align-middle shadow-xl transition-all">
                  <div className="flex justify-between items-center">
                    <Dialog.Title
                      as="h3"
                      className="text-lg font-medium leading-6 text-gray-900"
                      onClick={handleRedeem}
                    >
                      Redeem
                    </Dialog.Title>

                    <div className="">
                      <button
                        type="button"
                        className="rounded-md border border-transparent text-xl font-medium text-black hover:bg-blue-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2"
                        onClick={closeModal}
                      >
                        X
                      </button>
                    </div>
                  </div>

                  <div>
                    Vault Shares:{" "}
                    {data?.[2] ? data[2].toString() : "Not Connected"}
                  </div>

                  <div>Assets: {assetsAmount && assetsAmount.toString()}</div>

                  <div className="my-8 flex justify-between items-center gap-4">
                    <input
                      className="shadow appearance-none border border-gray-500 w-full rounded py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
                      type="text"
                      value={redeem}
                      onChange={handleChange}
                    />

                    <button
                      className="rounded-md border border-black px-2 py-1 border-transparent text-lg font-medium text-black hover:bg-blue-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2"
                      onClick={setMaxAmount}
                    >
                      Max
                    </button>
                  </div>

                  <div className="flex justify-between items-center gap-3">
                    <button
                      className="w-full rounded-md border border-black px-2 py-1 border-transparent text-lg font-medium text-black hover:bg-blue-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2"
                      onClick={handleRedeem}
                    >
                      Redeem
                    </button>
                  </div>
                </Dialog.Panel>
              </Transition.Child>
            </div>
          </div>
        </Dialog>
      </Transition>
    </>
  );
};

export default RedeemModal;
